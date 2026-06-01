import SwiftUI
import UIKit
import PhotosUI
import Photos

struct ProfileView: View {
    @EnvironmentObject var vm: EncounterViewModel

    @AppStorage("profile.firstName") private var firstName: String = ""
    @AppStorage("profile.birthDate") private var birthDateTimestamp: Double = Date().addingTimeInterval(-25 * 365.25 * 24 * 60 * 60).timeIntervalSince1970
    @AppStorage("profile.gender") private var gender: String = "Non précisé"
    @AppStorage("profile.city") private var city: String = ""
    @AppStorage("profile.bio") private var bio: String = ""
    @AppStorage("profile.imageBase64") private var imageBase64: String = ""
    @AppStorage("profile.customEmoji") private var customEmoji: String = ""
    @AppStorage("profile.customEmojiBgHex") private var customEmojiBgHex: String = "#C084FC"

    @State private var showDeleteAll = false
    @AppStorage("settings.theme") private var theme: String = "sombre"
    @AppStorage("settings.biometricLock") private var biometricLock: Bool = false
    @AppStorage("settings.autolockSeconds") private var autoLockSeconds: Int = 0
    @State private var showPhotoSourceDialog = false
    @State private var showSystemPhotoPicker = false
    @State private var selectedPhotoItem: PhotosPickerItem?
    @State private var showPhotoPicker = false
    @State private var showEmojiEditor = false
    @State private var photoAccessAlertMessage = ""
    @State private var showPhotoAccessAlert = false

    private let genders = ["Non précisé", "Femme", "Homme", "Non-binaire", "Autre"]
    private let emojiSuggestions: [String] = ["😀","😎","🥰","😘","🤩","😈","🥳","🤍","🔥","✨","🌹","🦋","🍸","🎵","☕️","🌙"]
    private let emojiColorPresets: [Color] = [
        Color(hex: "#C084FC"), Color(hex: "#F472B6"), Color(hex: "#60A5FA"),
        Color(hex: "#34D399"), Color(hex: "#F59E0B"), Color(hex: "#F87171"),
        Color(hex: "#A3A3A3"), Color(hex: "#1F2937")
    ]

    private var firstNameBinding: Binding<String> {
        Binding(
            get: { firstName },
            set: { firstName = InputSanitizer.cleanSingleLine($0, maxLength: 60) }
        )
    }

    private var cityBinding: Binding<String> {
        Binding(
            get: { city },
            set: { city = InputSanitizer.cleanSingleLine($0, maxLength: 80) }
        )
    }

    private var bioBinding: Binding<String> {
        Binding(
            get: { bio },
            set: { bio = InputSanitizer.cleanMultiLine($0, maxLength: 500) }
        )
    }
    
    private var birthDateBinding: Binding<Date> {
        Binding(
            get: { Date(timeIntervalSince1970: birthDateTimestamp) },
            set: { birthDateTimestamp = $0.timeIntervalSince1970 }
        )
    }
    
    private var computedAge: Int {
        let calendar = Calendar.current
        let birthDate = Date(timeIntervalSince1970: birthDateTimestamp)
        let years = calendar.dateComponents([.year], from: birthDate, to: Date()).year ?? 0
        return max(0, years)
    }
    
    var body: some View {
        NavigationStack {
            List {
                Section {
                    VStack(spacing: 14) {
                        Button {
                            showPhotoSourceDialog = true
                        } label: {
                            AvatarView(
                                initials: firstName.isEmpty ? "?" : String(firstName.prefix(2)).uppercased(),
                                gender: nil,
                                photoDataBase64: imageBase64,
                                customEmoji: customEmoji,
                                customEmojiBackgroundHex: customEmojiBgHex,
                                size: 108
                            )
                        }
                        .buttonStyle(.plain)

                        VStack(spacing: 4) {
                            Text(firstName.isEmpty ? "Mon profil" : firstName)
                                .font(.title3.bold())
                            Text("\(vm.totalCount) rencontre\(vm.totalCount > 1 ? "s" : "") enregistrée\(vm.totalCount > 1 ? "s" : "")")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                }

                Section("Informations") {
                    TextField("Prénom", text: firstNameBinding)
                    
                    DatePicker(
                        "Date de naissance",
                        selection: birthDateBinding,
                        in: ...Date(),
                        displayedComponents: .date
                    )
                    .environment(\.locale, Locale(identifier: "fr_FR"))
                    
                    HStack {
                        Text("Âge")
                        Spacer()
                        Text("\(computedAge) ans")
                            .foregroundColor(.secondary)
                    }

                    Picker("Genre", selection: $gender) {
                        ForEach(genders, id: \.self) { g in
                            Text(g).tag(g)
                        }
                    }

                    TextField("Ville", text: cityBinding)
                }

                Section("Bio") {
                    TextEditor(text: bioBinding)
                        .frame(minHeight: 90)
                }

                Section("Paramètres") {
                    Picker("Thème", selection: $theme) {
                        Text("Sombre").tag("sombre")
                        Text("Clair").tag("light")
                    }
                    
                    Toggle("Ouvrir avec Face ID / Touch ID", isOn: $biometricLock)
                        .tint(.themeAccent)

                    if biometricLock {
                        Picker("Verrouillage auto", selection: $autoLockSeconds) {
                            Text("Immédiat").tag(0)
                            Text("30 secondes").tag(30)
                            Text("1 minute").tag(60)
                        }
                    }
                    
                }

                Section {
                    Button(role: .destructive) {
                        showDeleteAll = true
                    } label: {
                        Label("Supprimer toutes les entrées", systemImage: "trash.fill")
                    }
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("Profil")
            .sheet(isPresented: $showPhotoPicker) {
                ImagePicker(sourceType: .camera, allowsEditing: true) { image in
                    if let jpegData = image.jpegData(compressionQuality: 0.85) {
                        imageBase64 = jpegData.base64EncodedString()
                    }
                }
            }
            .photosPicker(
                isPresented: $showSystemPhotoPicker,
                selection: $selectedPhotoItem,
                matching: .images
            )
            .onChange(of: selectedPhotoItem) { newItem in
                guard let newItem else { return }
                Task {
                    if let data = try? await newItem.loadTransferable(type: Data.self),
                       let image = UIImage(data: data),
                       let jpegData = image.jpegData(compressionQuality: 0.85) {
                        await MainActor.run {
                            imageBase64 = jpegData.base64EncodedString()
                            selectedPhotoItem = nil
                        }
                    }
                }
            }
            .confirmationDialog("Photo de profil", isPresented: $showPhotoSourceDialog, titleVisibility: .visible) {
                Button("Choisir une photo") {
                    requestPhotoLibraryAccessAndOpenPicker()
                }
                if UIImagePickerController.isSourceTypeAvailable(.camera) {
                    Button("Prendre une photo") {
                        showPhotoPicker = true
                    }
                }
                Button("Personnaliser avec un emoji") {
                    showEmojiEditor = true
                }
                if !imageBase64.isEmpty {
                    Button("Supprimer la photo", role: .destructive) {
                        imageBase64 = ""
                    }
                }
                Button("Annuler", role: .cancel) {}
            }
            .sheet(isPresented: $showEmojiEditor) {
                NavigationStack {
                    ScrollView {
                        VStack(spacing: 18) {
                            AvatarView(
                                initials: firstName.isEmpty ? "?" : String(firstName.prefix(2)).uppercased(),
                                gender: nil,
                                photoDataBase64: "",
                                customEmoji: customEmoji,
                                customEmojiBackgroundHex: customEmojiBgHex,
                                size: 92
                            )
                            .padding(.top, 6)
                            
                            VStack(alignment: .leading, spacing: 10) {
                                Text("Emoji")
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundColor(.secondary)

                                TextField("Emoji personnalisé", text: Binding(
                                    get: { customEmoji },
                                    set: { customEmoji = InputSanitizer.cleanEmoji($0) }
                                ))
                                .textInputAutocapitalization(.never)
                                .autocorrectionDisabled()

                                LazyVGrid(columns: [GridItem(.adaptive(minimum: 44))], spacing: 10) {
                                    ForEach(emojiSuggestions, id: \.self) { emoji in
                                        Button {
                                            customEmoji = InputSanitizer.cleanEmoji(emoji)
                                        } label: {
                                            Text(emoji)
                                                .font(.system(size: 24))
                                                .frame(width: 40, height: 40)
                                                .background(Color.themeSurface)
                                                .clipShape(RoundedRectangle(cornerRadius: 10))
                                        }
                                        .buttonStyle(.plain)
                                    }
                                }
                            }
                            
                            VStack(alignment: .leading, spacing: 10) {
                                Text("Couleur de fond")
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundColor(.secondary)
                                
                                HStack(spacing: 12) {
                                    ForEach(Array(emojiColorPresets.enumerated()), id: \.offset) { _, color in
                                        Button {
                                            customEmojiBgHex = color.toHexString()
                                        } label: {
                                            Circle()
                                                .fill(color)
                                                .frame(width: 30, height: 30)
                                                .overlay(
                                                    Circle()
                                                        .stroke(
                                                            customEmojiBgHex == color.toHexString()
                                                            ? Color.themeAccent : Color.clear,
                                                            lineWidth: 2
                                                        )
                                                )
                                        }
                                        .buttonStyle(.plain)
                                    }
                                }
                            }
                        }
                        .padding(.horizontal)
                        .padding(.bottom)
                    }
                    .navigationTitle("Avatar Emoji")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .navigationBarTrailing) {
                            Button("OK") { showEmojiEditor = false }
                                .foregroundColor(.themeAccent)
                        }
                    }
                }
            }
            .alert("Tout supprimer ?", isPresented: $showDeleteAll) {
                Button("Supprimer", role: .destructive) {
                    vm.clearAll()
                }
                Button("Annuler", role: .cancel) {}
            } message: {
                Text("Cette action est irréversible.")
            }
            .alert("Accès Photos requis", isPresented: $showPhotoAccessAlert) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(photoAccessAlertMessage)
            }
        }
    }
    
    private func requestPhotoLibraryAccessAndOpenPicker() {
        let status = PHPhotoLibrary.authorizationStatus(for: .readWrite)
        switch status {
        case .authorized, .limited:
            showSystemPhotoPicker = true
        case .notDetermined:
            PHPhotoLibrary.requestAuthorization(for: .readWrite) { newStatus in
                Task { @MainActor in
                    if newStatus == .authorized || newStatus == .limited {
                        showSystemPhotoPicker = true
                    } else {
                        photoAccessAlertMessage = "Autorise l’accès aux photos dans Réglages > Body X > Photos."
                        showPhotoAccessAlert = true
                    }
                }
            }
        case .denied, .restricted:
            photoAccessAlertMessage = "L’accès à la photothèque est refusé. Ouvre Réglages > Body X > Photos et autorise l’accès."
            showPhotoAccessAlert = true
        @unknown default:
            photoAccessAlertMessage = "Impossible d’accéder à la photothèque pour le moment."
            showPhotoAccessAlert = true
        }
    }
}
