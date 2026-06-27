//
//  EditProfileView.swift
//  HoopScout
//

import SwiftUI
import PhotosUI

struct EditProfileView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var auth: AuthService

    @State private var name: String = ""
    @State private var handle: String = ""
    @State private var location: String = ""
    @State private var bio: String = ""
    @State private var skill: String = "Casual"
    @State private var photoURL: String?

    @State private var pickerItem: PhotosPickerItem?
    @State private var pickedImage: UIImage?
    @State private var uploading = false
    @State private var saving = false
    @State private var errorMessage: String?
    @State private var didLoad = false
    @State private var showPhotoSourceDialog = false
    @State private var showPhotoLibrary = false
    @State private var showCamera = false

    var body: some View {
        ZStack {
            HSColors.bg.ignoresSafeArea()
            ScrollView {
                VStack(spacing: 18) {
                    avatar
                    if let errorMessage {
                        Text(errorMessage)
                            .font(.system(size: 12))
                            .foregroundColor(.red.opacity(0.85))
                            .multilineTextAlignment(.center)
                    }
                    section("Account") {
                        field("Name", text: $name)
                        field("Handle", text: $handle)
                        field("Location", text: $location)
                    }
                    section("Bio") {
                        TextEditor(text: $bio)
                            .font(.system(size: 14))
                            .frame(minHeight: 96)
                            .padding(.horizontal, 10).padding(.vertical, 8)
                            .background(Color.white)
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                            .overlay(
                                RoundedRectangle(cornerRadius: 10)
                                    .stroke(HSColors.gray200, lineWidth: 1)
                            )
                    }
                    section("Skill level") {
                        Picker("Skill", selection: $skill) {
                            Text("Casual").tag("Casual")
                            Text("Competitive").tag("Competitive")
                        }
                        .pickerStyle(.segmented)
                    }
                    Spacer(minLength: 40)
                }
                .padding(.horizontal, 16).padding(.top, 12).padding(.bottom, 32)
            }
        }
        .navigationTitle("Edit profile")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button(saving ? "Saving…" : "Save") {
                    Task { await save() }
                }
                .foregroundColor(HSColors.navy)
                .fontWeight(.bold)
                .disabled(saving || uploading)
            }
        }
        .onAppear { loadFromAuthIfNeeded() }
        .onChange(of: pickerItem) { _, newItem in
            guard let newItem else { return }
            Task { await handlePickedItem(newItem) }
        }
        .photosPicker(isPresented: $showPhotoLibrary,
                      selection: $pickerItem,
                      matching: .images,
                      photoLibrary: .shared())
        .sheet(isPresented: $showCamera) {
            CameraImagePicker { image in
                guard let image else { return }
                Task { await handleCapturedImage(image) }
            }
            .ignoresSafeArea()
        }
        .confirmationDialog("Profile photo", isPresented: $showPhotoSourceDialog, titleVisibility: .hidden) {
            if UIImagePickerController.isSourceTypeAvailable(.camera) {
                Button("Take Photo") { showCamera = true }
            }
            Button("Choose from Library") { showPhotoLibrary = true }
            Button("Cancel", role: .cancel) {}
        }
    }

    private var avatar: some View {
        VStack(spacing: 10) {
            ZStack {
                if let pickedImage {
                    Image(uiImage: pickedImage)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 80, height: 80)
                        .clipShape(Circle())
                        .overlay(Circle().stroke(Color.white, lineWidth: 3))
                } else if let profile = auth.profile {
                    HSAvatar(profile: previewProfile(profile), size: 80)
                        .overlay(Circle().stroke(Color.white, lineWidth: 3))
                }
                if uploading {
                    Circle().fill(Color.black.opacity(0.45)).frame(width: 80, height: 80)
                    ProgressView().tint(.white)
                }
            }
            Button {
                showPhotoSourceDialog = true
            } label: {
                Text(uploading ? "Uploading…" : "Change photo")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(HSColors.navy)
            }
            .disabled(uploading || saving)
        }
        .padding(.top, 8)
    }

    private func previewProfile(_ profile: HSUserProfile) -> HSUserProfile {
        var copy = profile
        copy.photoURL = photoURL ?? profile.photoURL
        return copy
    }

    private func section<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title.uppercased())
                .font(.system(size: 11, weight: .bold))
                .kerning(1.2)
                .foregroundColor(HSColors.gray500)
                .padding(.leading, 4)
            VStack(spacing: 10) { content() }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func field(_ label: String, text: Binding<String>) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label).font(.system(size: 12)).foregroundColor(HSColors.gray500)
            TextField(label, text: text)
                .font(.system(size: 15))
                .padding(.horizontal, 12).frame(height: 44)
                .background(Color.white)
                .overlay(RoundedRectangle(cornerRadius: 10).stroke(HSColors.gray200, lineWidth: 1))
                .clipShape(RoundedRectangle(cornerRadius: 10))
        }
    }

    // MARK: - Actions

    private func loadFromAuthIfNeeded() {
        guard !didLoad, let p = auth.profile else { return }
        name = p.name
        handle = p.handle
        location = p.location
        bio = p.bio
        skill = p.skill
        photoURL = p.photoURL
        didLoad = true
    }

    private func handlePickedItem(_ item: PhotosPickerItem) async {
        errorMessage = nil
        do {
            guard let data = try await item.loadTransferable(type: Data.self),
                  let image = UIImage(data: data) else {
                errorMessage = "Couldn't read that image."
                return
            }
            await uploadAvatarImage(image)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func handleCapturedImage(_ image: UIImage) async {
        errorMessage = nil
        await uploadAvatarImage(image)
    }

    private func uploadAvatarImage(_ image: UIImage) async {
        guard let uid = auth.profile?.id else {
            errorMessage = "Sign in required."
            return
        }
        pickedImage = image
        uploading = true
        defer { uploading = false }
        do {
            let url = try await ProfilePhotoService.shared.uploadAvatar(image, uid: uid)
            photoURL = url
            try await UserRepository.shared.setPhotoURL(url, uid: uid)
            // Refresh local profile so HSAvatar across the app updates.
            if var current = auth.profile {
                current.photoURL = url
                auth.applyLocalProfileUpdate(current)
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func save() async {
        guard var profile = auth.profile else {
            errorMessage = "Sign in required."
            return
        }
        saving = true
        defer { saving = false }
        profile.name = name.trimmingCharacters(in: .whitespacesAndNewlines)
        profile.handle = handle.trimmingCharacters(in: .whitespacesAndNewlines)
        profile.location = location.trimmingCharacters(in: .whitespacesAndNewlines)
        profile.bio = bio
        profile.skill = skill
        if let photoURL { profile.photoURL = photoURL }
        do {
            try await UserRepository.shared.update(profile)
            auth.applyLocalProfileUpdate(profile)
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

private struct CameraImagePicker: UIViewControllerRepresentable {
    var onPicked: (UIImage?) -> Void

    func makeCoordinator() -> Coordinator { Coordinator(onPicked: onPicked) }

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = .camera
        picker.cameraDevice = .front
        picker.allowsEditing = true
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    final class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let onPicked: (UIImage?) -> Void
        init(onPicked: @escaping (UIImage?) -> Void) { self.onPicked = onPicked }

        func imagePickerController(_ picker: UIImagePickerController,
                                   didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
            let image = (info[.editedImage] as? UIImage) ?? (info[.originalImage] as? UIImage)
            picker.dismiss(animated: true) { self.onPicked(image) }
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            picker.dismiss(animated: true) { self.onPicked(nil) }
        }
    }
}

#Preview {
    NavigationStack { EditProfileView() }
        .environmentObject(AuthService())
}
