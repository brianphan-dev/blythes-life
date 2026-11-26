import BlythesLifeCore
import BlythesLifeDesignSystem
import BlythesLifeShared
import SwiftUI
import UniformTypeIdentifiers
#if canImport(AuthenticationServices)
import AuthenticationServices
#endif
#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

/// Transferable raw-data document for lossless JSON and pediatrician CSV exports.
private struct BLExportFileDocument: FileDocument, Sendable {
    static let readableContentTypes: [UTType] = [.json, .commaSeparatedText, .plainText]

    let data: Data

    init(data: Data) {
        self.data = data
    }

    init(configuration: ReadConfiguration) throws {
        self.data = configuration.file.regularFileContents ?? Data()
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: data)
    }
}

/// Settings screen matching `SettingsScreen.jsx` plus live Device Posture Preview,
/// interactive Nap Schedule editor, Household members/invite management, Huckleberry CSV import,
/// lossless JSON & pediatrician CSV export, and Sign in with Apple / Account Deletion.
@MainActor
public struct SettingsView: View {
    @Environment(\.blTheme) private var theme
    @Environment(\.blColorMode) private var colorMode
    @Environment(\.duoLayout) private var duoLayout

    private let store: BlythesLifeStore

    @State private var isBabyProfileSheetOpen = false
    @State private var isScheduleSheetOpen = false
    @State private var isMembersSheetOpen = false
    @State private var isJoinHouseholdSheetOpen = false
    @State private var isImportingCSV = false
    @State private var isExportingFile = false
    @State private var exportDocument: BLExportFileDocument?
    @State private var exportContentType: UTType = .json
    @State private var exportFilename: String = "blythes-life-backup.json"
    @State private var isDeleteAccountAlertOpen = false
    @State private var pendingRawNonce: String?
    @State private var isCheckingConnection = false
    @State private var lastServerCheckOK = false
    @State private var isRotatingInviteCode = false
    @State private var isSigningOut = false
    @State private var isDeletingAccount = false

    public init(store: BlythesLifeStore) {
        self.store = store
    }

    public var body: some View {
        ZStack {
            HingeSplitContainer(
                padLeadingRatio: 0.50,
                leading: {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 0) {
                            headerView
                                .padding(.horizontal, -BLSpacing.screenGutter)
                            babyProfileGroup
                            napScheduleGroup
                            loggingGroup
                            posturePreviewGroup
                        }
                        .padding(.horizontal, BLSpacing.screenGutter)
                        .padding(.bottom, BLSpacing.space6)
                    }
                    .scrollIndicators(.hidden)
                    .background(theme.bgApp)
                },
                trailing: {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 0) {
                            householdGroup
                            dataGroup
                            accountGroup
                        }
                        .padding(.horizontal, BLSpacing.screenGutter)
                        .padding(.top, BLSpacing.space2)
                        .padding(.bottom, BLSpacing.space6)
                    }
                    .scrollIndicators(.hidden)
                    .background(theme.bgApp)
                },
                compact: {
                    VStack(spacing: 0) {
                        headerView

                        ScrollView {
                            VStack(alignment: .leading, spacing: 0) {
                                babyProfileGroup
                                napScheduleGroup
                                loggingGroup
                                posturePreviewGroup
                                householdGroup
                                dataGroup
                                accountGroup
                            }
                            .padding(.horizontal, BLSpacing.screenGutter)
                            .padding(.bottom, BLSpacing.space6)
                        }
                        .scrollIndicators(.hidden)
                    }
                    .background(theme.bgApp)
                }
            )
            .background(theme.bgApp)

            if isBabyProfileSheetOpen {
                BabyProfileEditorSheet(
                    initialName: store.profile.displayName,
                    initialBirthDate: Self.parseISOBirthDate(store.profile.birthDate),
                    onClose: { isBabyProfileSheetOpen = false },
                    onSave: { displayName, birthDate in
                        try await store.updateBabyProfileAsync(
                            displayName: displayName,
                            birthDate: birthDate
                        )
                        isBabyProfileSheetOpen = false
                    }
                )
                .zIndex(10)
            }

            if isScheduleSheetOpen {
                NapScheduleEditorSheet(
                    initialConfig: store.profile.scheduleConfig,
                    onClose: { isScheduleSheetOpen = false },
                    onSave: { updated in
                        store.updateScheduleConfig(updated)
                        isScheduleSheetOpen = false
                    }
                )
                .zIndex(10)
            }

            if isMembersSheetOpen {
                HouseholdMembersSheet(
                    household: store.household,
                    formattedInviteCode: store.formattedInviteCode,
                    isRotatingCode: isRotatingInviteCode,
                    onCopyCode: copyInviteCode,
                    onRotateCode: rotateInviteCode,
                    onClose: { isMembersSheetOpen = false }
                )
                .zIndex(10)
            }

            if isJoinHouseholdSheetOpen {
                JoinHouseholdSheet(
                    initialDisplayName: store.displayName ?? "",
                    hasLiveSession: store.hasLiveSession,
                    onClose: { isJoinHouseholdSheetOpen = false },
                    onJoin: { code, name in
                        try await store.joinHouseholdAsync(inviteCode: code, displayName: name)
                        isJoinHouseholdSheetOpen = false
                    }
                )
                .zIndex(10)
            }
        }
        .fileImporter(
            isPresented: $isImportingCSV,
            allowedContentTypes: [.commaSeparatedText, .plainText],
            allowsMultipleSelection: false
        ) { result in
            handleHuckleberryCSVImport(result)
        }
        .fileExporter(
            isPresented: $isExportingFile,
            document: exportDocument,
            contentType: exportContentType,
            defaultFilename: exportFilename
        ) { result in
            switch result {
            case .success:
                store.showInfoToast(
                    exportContentType == .json ? "Backup exported" : "Pediatrician CSV exported"
                )
            case .failure:
                store.showInfoToast("Export cancelled")
            }
        }
        .alert("Delete account", isPresented: $isDeleteAccountAlertOpen) {
            Button("Cancel", role: .cancel) {}
            Button("Delete account", role: .destructive) {
                deleteAccount()
            }
        } message: {
            Text("This permanently removes your account and entries on every device. Export a backup first if you want a copy.")
        }
    }

    // MARK: - Header

    private var headerView: some View {
        HStack(alignment: .bottom) {
            VStack(alignment: .leading, spacing: 2) {
                Text(store.household.name)
                    .blMicroLabel()
                Text("Settings")
                    .blTextRole(.display)
                    .foregroundStyle(theme.textPrimary)
            }
            Spacer()
        }
        .padding(.top, 6)
        .padding(.horizontal, BLSpacing.screenGutter)
        .padding(.bottom, BLSpacing.space3)
    }

    // MARK: - Settings Groups

    private var babyProfileGroup: some View {
        settingsGroup(title: "Baby profile") {
            BLCard(isFlush: true) {
                VStack(spacing: 0) {
                    BLListRow(
                        label: "Name",
                        value: store.profile.displayName,
                        showsChevron: true,
                        onTap: { isBabyProfileSheetOpen = true }
                    )
                    BLListRow(
                        label: "Birth date",
                        detail: store.profileAgeLabel.isEmpty ? nil : store.profileAgeLabel,
                        value: formattedBirthDateDisplay,
                        showsChevron: true,
                        showDivider: false,
                        onTap: { isBabyProfileSheetOpen = true }
                    )
                }
            }
        }
    }

    private var napScheduleGroup: some View {
        let config = store.profile.scheduleConfig
        let ww1 = config.wakeWindowsMinutes.first ?? 150
        let ww2 = config.wakeWindowsMinutes.count > 1 ? config.wakeWindowsMinutes[1] : 195

        return settingsGroup(title: "Nap schedule") {
            BLCard(isFlush: true) {
                VStack(spacing: 0) {
                    BLListRow(
                        label: "Awake before nap 1",
                        value: FormattingHelpers.formatWakeWindowFraction(minutes: ww1),
                        showsChevron: true,
                        onTap: { isScheduleSheetOpen = true }
                    )
                    BLListRow(
                        label: "Awake before nap 2",
                        value: FormattingHelpers.formatWakeWindowFraction(minutes: ww2),
                        showsChevron: true,
                        onTap: { isScheduleSheetOpen = true }
                    )
                    BLListRow(
                        label: "Nap cap",
                        value: FormattingHelpers.formatWakeWindowFraction(minutes: config.napCapMinutes),
                        showsChevron: true,
                        onTap: { isScheduleSheetOpen = true }
                    )
                    BLListRow(
                        label: "Backup catnap cutoff",
                        value: FormattingHelpers.formatMinutesFromMidnight(
                            config.backupCatnapCutoffMinutesFromMidnight
                        ),
                        showsChevron: true,
                        showDivider: false,
                        onTap: { isScheduleSheetOpen = true }
                    )
                }
            }
        }
    }

    private var loggingGroup: some View {
        let unitBinding = Binding<VolumeUnit>(
            get: { store.preferredUnit },
            set: { store.setPreferredUnit($0) }
        )
        let nightBinding = Binding<Bool>(
            get: { store.colorModePreference == .night },
            set: { store.setColorMode($0 ? .night : .day) }
        )

        return settingsGroup(title: "Logging") {
            BLCard(isFlush: true) {
                VStack(spacing: 0) {
                    BLListRow(label: "Bottle unit") {
                        BLSegmentedControl(
                            options: [VolumeUnit.oz, .ml],
                            selection: unitBinding,
                            size: .sm
                        ) { $0 == .oz ? "oz" : "mL" }
                    }
                    BLListRow(
                        label: "Night mode",
                        detail: "True black with warm, dim text",
                        showDivider: false
                    ) {
                        BLSwitch(isOn: nightBinding, label: "Night mode")
                    }
                }
            }
        }
    }

    private var posturePreviewGroup: some View {
        settingsGroup(title: "Device posture (Preview)") {
            BLCard {
                VStack(alignment: .leading, spacing: BLSpacing.space3) {
                    Text("Test every iPhone, iPhone Duo, and iPad layout on this screen.")
                        .blTextRole(.caption)
                        .foregroundStyle(theme.textSecondary)

                    BLFlowLayout(horizontalSpacing: BLSpacing.space2, verticalSpacing: BLSpacing.space2) {
                        ForEach(PosturePreviewOverride.allCases) { option in
                            BLChip(
                                option.shortTitle,
                                isSelected: store.postureOverride == option
                            ) {
                                store.setPostureOverride(option)
                            }
                        }
                    }

                    Text("Active: \(activePostureDescription)")
                        .blTextRole(.caption)
                        .foregroundStyle(theme.textTertiary)
                }
            }
        }
    }

    private var householdGroup: some View {
        let memberCount = store.household.members?.count ?? 1

        return settingsGroup(title: "Household") {
            BLCard(isFlush: true) {
                VStack(spacing: 0) {
                    BLListRow(
                        icon: BLSymbol.members,
                        label: "Members",
                        value: "\(memberCount)",
                        showsChevron: true,
                        onTap: { isMembersSheetOpen = true }
                    )
                    BLListRow(
                        icon: BLSymbol.inviteKey,
                        label: "Invite code",
                        detail: "Tap to copy",
                        value: store.formattedInviteCode,
                        showDivider: true,
                        onTap: copyInviteCode
                    ) {
                        BLButton(
                            isRotatingInviteCode ? "Updating…" : "Rotate",
                            variant: .secondary,
                            size: .sm,
                            action: rotateInviteCode
                        )
                        .disabled(isRotatingInviteCode)
                    }
                    BLListRow(
                        icon: "person.badge.plus",
                        label: "Join a household",
                        detail: "Enter a 6-digit invite code",
                        showsChevron: true,
                        showDivider: false,
                        onTap: { isJoinHouseholdSheetOpen = true }
                    )
                }
            }
        }
    }

    private var dataGroup: some View {
        settingsGroup(title: "Your data") {
            BLCard(isFlush: true) {
                VStack(spacing: 0) {
                    BLListRow(
                        icon: BLSymbol.importFile,
                        label: "Import from Huckleberry",
                        detail: "CSV. Re-importing never duplicates.",
                        onTap: { isImportingCSV = true }
                    )
                    BLListRow(
                        icon: BLSymbol.exportFile,
                        label: "Export everything",
                        detail: "JSON bundle you can re-import",
                        onTap: startJSONExport
                    )
                    BLListRow(
                        icon: BLSymbol.document,
                        label: "Export for the pediatrician",
                        detail: "Readable CSV",
                        showDivider: false,
                        onTap: startPediatricianCSVExport
                    )
                }
            }
        }
    }

    private var accountGroup: some View {
        let showsDeleteAccount = !store.isDemoPreview
        let connectionShowsDivider = store.isSignedInWithApple || showsDeleteAccount

        return settingsGroup(title: "Account") {
            BLCard(isFlush: true) {
                VStack(spacing: 0) {
                    if store.isDemoPreview {
                        BLListRow(
                            label: "Sample preview",
                            detail: "Showing example entries locally. Exit to sign in with Apple."
                        ) {
                            BLButton("Exit preview", variant: .secondary, size: .sm) {
                                store.exitDemoPreview()
                            }
                        }
                    }

                    appleSignInSection

                    BLListRow(
                        label: connectionStatusTitle,
                        detail: connectionStatusDetail,
                        showDivider: connectionShowsDivider
                    ) {
                        BLButton(
                            isCheckingConnection
                                ? "Checking…"
                                : (store.hasLiveSession ? "Refresh" : "Check connection"),
                            variant: .secondary,
                            size: .sm
                        ) {
                            checkConnection()
                        }
                        .disabled(isCheckingConnection || store.isAuthenticating)
                    }

                    if store.isSignedInWithApple {
                        BLListRow(
                            label: isSigningOut ? "Signing out…" : "Sign out",
                            isDanger: true,
                            showDivider: showsDeleteAccount,
                            onTap: {
                                signOutOnThisDevice()
                            }
                        )
                        .disabled(isSigningOut || isDeletingAccount)
                        .opacity(isSigningOut ? 0.5 : 1.0)
                    }

                    if showsDeleteAccount {
                        BLListRow(
                            label: isDeletingAccount ? "Deleting account…" : "Delete account",
                            detail: "Removes your account and entries on every device",
                            isDanger: true,
                            showDivider: false,
                            onTap: {
                                isDeleteAccountAlertOpen = true
                            }
                        )
                        .disabled(isDeletingAccount || isSigningOut)
                        .opacity(isDeletingAccount ? 0.5 : 1.0)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var appleSignInSection: some View {
        if store.isSignedInWithApple {
            BLListRow(
                label: "Signed in with Apple",
                detail: signedInIdentityDetail
            )
        } else {
            #if canImport(AuthenticationServices)
            VStack(alignment: .leading, spacing: BLSpacing.space2) {
                Text(
                    store.isAuthenticating
                        ? "Signing in with Apple…"
                        : "Sign in to keep entries updated on every device"
                )
                .blTextRole(.caption)
                .foregroundStyle(theme.textSecondary)

                SignInWithAppleButton(.signIn) { request in
                    let raw = AppleNonceGenerator.randomNonceString()
                    pendingRawNonce = raw
                    request.nonce = AppleNonceGenerator.sha256Hex(raw)
                    request.requestedScopes = [.fullName, .email]
                } onCompletion: { result in
                    handleAppleSignIn(result)
                }
                .id(colorMode)
                .signInWithAppleButtonStyle(colorMode == .night ? .white : .black)
                .frame(height: 48)
                .clipShape(RoundedRectangle(cornerRadius: BLRadius.md, style: .continuous))
                .disabled(store.isAuthenticating)
                .opacity(store.isAuthenticating ? 0.5 : 1.0)

                if store.isAuthenticating {
                    HStack(spacing: BLSpacing.space2) {
                        ProgressView()
                            .controlSize(.small)
                            .tint(theme.accentText)
                        Text("Connecting your account…")
                            .blTextRole(.caption)
                            .foregroundStyle(theme.textSecondary)
                    }
                    .padding(.top, BLSpacing.space1)
                }
            }
            .padding(BLSpacing.space4)
            .overlay(alignment: .bottom) {
                Rectangle()
                    .fill(theme.borderHairline)
                    .frame(height: BLSpacing.borderWidth)
            }
            #else
            BLListRow(
                label: "Sign in with Apple",
                detail: "Not signed in"
            )
            #endif
        }
    }

    private func settingsGroup<Content: View>(
        title: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: BLSpacing.space2) {
            Text(title)
                .blMicroLabel()
                .padding(.top, BLSpacing.space5)
            content()
        }
    }

    // MARK: - Helpers & Actions

    private var activePostureDescription: String {
        switch duoLayout.posture {
        case .compactPhone: "iPhone"
        case .duoFolded: "iPhone Duo · Folded"
        case .duoUnfolded: "iPhone Duo · Unfolded"
        case .duoTabletop: "iPhone Duo · Tabletop"
        case .iPadRegular: "iPad"
        }
    }

    private var apiHostLabel: String {
        URL(string: store.apiBaseURLString)?.host ?? "api.blythe.brianphan.dev"
    }

    private var signedInIdentityDetail: String? {
        let parts = [store.displayName, store.authEmail]
            .compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        return parts.isEmpty ? nil : parts.joined(separator: " · ")
    }

    private var formattedBirthDateDisplay: String {
        guard let date = Self.parseISOBirthDate(store.profile.birthDate) else {
            return "Not set"
        }
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.timeZone = TimeZone.current
        formatter.dateFormat = "MMM d, yyyy"
        return formatter.string(from: date)
    }

    private static func parseISOBirthDate(_ raw: String?) -> Date? {
        guard let trimmed = raw?.trimmingCharacters(in: .whitespacesAndNewlines), !trimmed.isEmpty else {
            return nil
        }
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.timeZone = TimeZone.current
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.date(from: trimmed)
    }

    private var connectionStatusTitle: String {
        if store.isDemoPreview {
            return "Sample preview"
        }
        switch store.syncStatus {
        case .synced:
            return "Updated on every device"
        case .syncing:
            return "Updating…"
        case .offline(let pendingCount):
            return "Offline · \(pendingCount) waiting"
        case .localOnly:
            return "Local preview"
        case .error:
            return "Needs a look"
        }
    }

    private var connectionStatusDetail: String {
        if store.isDemoPreview {
            return "Example entries on this device only"
        }
        switch store.syncStatus {
        case .synced(let date):
            let clock = FormattingHelpers.formatClock(date, timeZone: store.profileTimeZone)
            return "\(apiHostLabel) · \(clock)"
        case .syncing:
            return apiHostLabel
        case .offline:
            if let error = store.lastSyncError, !error.isEmpty {
                return error
            }
            return "Changes stay on this device until connected"
        case .localOnly:
            if lastServerCheckOK {
                return "Server connected · \(apiHostLabel)"
            }
            return "Entries stay on this device until you sign in"
        case .error(let detail):
            return detail.isEmpty ? "Could not reach server" : detail
        }
    }

    private func checkConnection() {
        guard !isCheckingConnection else { return }
        isCheckingConnection = true
        let host = apiHostLabel
        Task { @MainActor in
            defer { isCheckingConnection = false }
            await store.resumeLiveSession()
            let health = await store.checkBackendHealth()
            if health != nil {
                lastServerCheckOK = true
                if case .error(let detail) = store.syncStatus, !detail.isEmpty {
                    store.showInfoToast(detail)
                } else {
                    store.showInfoToast("Connected to \(host)")
                }
            } else {
                lastServerCheckOK = false
                if let error = store.lastSyncError, !error.isEmpty {
                    store.showInfoToast(error)
                } else {
                    store.showInfoToast("Could not reach \(host)")
                }
            }
        }
    }

    private func copyInviteCode() {
        let code = store.formattedInviteCode
        #if canImport(UIKit)
        UIPasteboard.general.string = code
        #elseif canImport(AppKit)
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(code, forType: .string)
        #endif
        store.showInfoToast("Invite code copied · \(code)")
    }

    private func rotateInviteCode() {
        guard !isRotatingInviteCode else { return }
        isRotatingInviteCode = true
        Task { @MainActor in
            defer { isRotatingInviteCode = false }
            await store.rotateInviteCodeAsync()
        }
    }

    private func signOutOnThisDevice() {
        guard !isSigningOut else { return }
        isSigningOut = true
        Task { @MainActor in
            defer { isSigningOut = false }
            await store.signOutOnThisDeviceAsync()
            lastServerCheckOK = false
        }
    }

    private func deleteAccount() {
        guard !isDeletingAccount else { return }
        isDeletingAccount = true
        Task { @MainActor in
            defer { isDeletingAccount = false }
            do {
                try await store.deleteAccountAsync()
                lastServerCheckOK = false
            } catch {
                store.showInfoToast(error.localizedDescription)
            }
        }
    }

    private func handleHuckleberryCSVImport(_ result: Result<[URL], any Error>) {
        switch result {
        case .success(let urls):
            guard let url = urls.first else { return }
            let accessed = url.startAccessingSecurityScopedResource()
            defer {
                if accessed { url.stopAccessingSecurityScopedResource() }
            }
            if let csv = try? String(contentsOf: url, encoding: .utf8) {
                store.importHuckleberryCSV(csv)
            } else {
                store.showInfoToast("Could not read CSV file")
            }
        case .failure:
            store.showInfoToast("Import cancelled")
        }
    }

    private func startJSONExport() {
        do {
            let data = try store.exportLosslessJSONData()
            exportDocument = BLExportFileDocument(data: data)
            exportContentType = .json
            exportFilename = "blythes-life-backup.json"
            isExportingFile = true
        } catch {
            store.showInfoToast("Could not prepare JSON export")
        }
    }

    private func startPediatricianCSVExport() {
        let csv = store.exportPediatricianCSVString()
        exportDocument = BLExportFileDocument(data: Data(csv.utf8))
        exportContentType = .commaSeparatedText
        exportFilename = "blythe-daily-log.csv"
        isExportingFile = true
    }

    #if canImport(AuthenticationServices)
    private func handleAppleSignIn(_ result: Result<ASAuthorization, any Error>) {
        let rawNonce = pendingRawNonce
        pendingRawNonce = nil

        switch result {
        case .success(let auth):
            guard let credential = auth.credential as? ASAuthorizationAppleIDCredential,
                  let tokenData = credential.identityToken,
                  let identityToken = String(data: tokenData, encoding: .utf8),
                  !identityToken.isEmpty,
                  let rawNonce,
                  !rawNonce.isEmpty
            else {
                store.showInfoToast("Could not complete Sign in with Apple")
                return
            }

            let authorizationCode = credential.authorizationCode.flatMap {
                String(data: $0, encoding: .utf8)
            }
            let formattedName: String? = credential.fullName.flatMap { components in
                let formatted = PersonNameComponentsFormatter().string(from: components)
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                return formatted.isEmpty ? nil : formatted
            }
            let trimmedEmail = credential.email?.trimmingCharacters(in: .whitespacesAndNewlines)
            let email = (trimmedEmail?.isEmpty == false) ? trimmedEmail : nil

            Task { @MainActor in
                do {
                    try await store.completeAppleSignIn(
                        identityToken: identityToken,
                        rawNonce: rawNonce,
                        authorizationCode: authorizationCode,
                        displayName: formattedName,
                        email: email
                    )
                    lastServerCheckOK = true
                } catch {
                    store.showInfoToast(error.localizedDescription)
                }
            }

        case .failure(let error):
            if let authError = error as? ASAuthorizationError, authError.code == .canceled {
                store.showInfoToast("Sign in with Apple was cancelled")
            } else {
                store.showInfoToast("Sign in with Apple could not be completed")
            }
        }
    }
    #endif
}

// MARK: - Nap Schedule Editor Sheet

private struct NapScheduleEditorSheet: View {
    @Environment(\.blTheme) private var theme

    let onClose: () -> Void
    let onSave: (ScheduleConfig) -> Void

    @State private var wakeWindow1: Int
    @State private var wakeWindow2: Int
    @State private var napCap: Int
    @State private var backupCutoff: Int
    private let baseConfig: ScheduleConfig

    init(
        initialConfig: ScheduleConfig,
        onClose: @escaping () -> Void,
        onSave: @escaping (ScheduleConfig) -> Void
    ) {
        self.baseConfig = initialConfig
        self.onClose = onClose
        self.onSave = onSave
        _wakeWindow1 = State(initialValue: initialConfig.wakeWindowsMinutes.first ?? 150)
        _wakeWindow2 = State(
            initialValue: initialConfig.wakeWindowsMinutes.count > 1
                ? initialConfig.wakeWindowsMinutes[1]
                : 195
        )
        _napCap = State(initialValue: initialConfig.napCapMinutes)
        _backupCutoff = State(initialValue: initialConfig.backupCatnapCutoffMinutesFromMidnight)
    }

    var body: some View {
        BLSheetContainer(
            isPresented: true,
            title: "Nap schedule",
            showScrim: true,
            onClose: onClose,
            icon: {
                BLEventIcon(kind: .sleep, size: .md)
            },
            content: {
                stepperRow(
                    label: "Awake before nap 1",
                    value: FormattingHelpers.formatWakeWindowFraction(minutes: wakeWindow1),
                    canDecrement: wakeWindow1 > 60,
                    canIncrement: wakeWindow1 < 300,
                    onDecrement: { wakeWindow1 = max(60, wakeWindow1 - 15) },
                    onIncrement: { wakeWindow1 = min(300, wakeWindow1 + 15) }
                )

                stepperRow(
                    label: "Awake before nap 2",
                    value: FormattingHelpers.formatWakeWindowFraction(minutes: wakeWindow2),
                    canDecrement: wakeWindow2 > 90,
                    canIncrement: wakeWindow2 < 360,
                    onDecrement: { wakeWindow2 = max(90, wakeWindow2 - 15) },
                    onIncrement: { wakeWindow2 = min(360, wakeWindow2 + 15) }
                )

                stepperRow(
                    label: "Nap cap",
                    value: FormattingHelpers.formatWakeWindowFraction(minutes: napCap),
                    canDecrement: napCap > 30,
                    canIncrement: napCap < 180,
                    onDecrement: { napCap = max(30, napCap - 15) },
                    onIncrement: { napCap = min(180, napCap + 15) }
                )

                stepperRow(
                    label: "Backup catnap cutoff",
                    value: FormattingHelpers.formatMinutesFromMidnight(backupCutoff),
                    canDecrement: backupCutoff > 840,
                    canIncrement: backupCutoff < 1140,
                    onDecrement: { backupCutoff = max(840, backupCutoff - 15) },
                    onIncrement: { backupCutoff = min(1140, backupCutoff + 15) }
                )
            },
            footer: {
                BLButton("Save schedule", variant: .primary, size: .lg, isBlock: true) {
                    var updated = baseConfig
                    updated.wakeWindowsMinutes = [wakeWindow1, wakeWindow2]
                    updated.napCapMinutes = napCap
                    updated.backupCatnapCutoffMinutesFromMidnight = backupCutoff
                    onSave(updated)
                }
            }
        )
    }

    private func stepperRow(
        label: String,
        value: String,
        canDecrement: Bool,
        canIncrement: Bool,
        onDecrement: @escaping () -> Void,
        onIncrement: @escaping () -> Void
    ) -> some View {
        HStack(spacing: BLSpacing.space3) {
            VStack(alignment: .leading, spacing: 2) {
                Text(label)
                    .blMicroLabel()
                Text(value)
                    .font(BLFont.display(size: 24, weight: .medium, tabularNumerals: true))
                    .foregroundStyle(theme.textPrimary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            HStack(spacing: BLSpacing.space2) {
                BLButton("−", variant: .secondary, size: .md, action: onDecrement)
                    .disabled(!canDecrement)
                    .accessibilityLabel("Decrease \(label)")

                BLButton("+", variant: .secondary, size: .md, action: onIncrement)
                    .disabled(!canIncrement)
                    .accessibilityLabel("Increase \(label)")
            }
        }
    }
}

// MARK: - Household Members Sheet

private struct HouseholdMembersSheet: View {
    @Environment(\.blTheme) private var theme

    let household: HouseholdDTO
    let formattedInviteCode: String
    let isRotatingCode: Bool
    let onCopyCode: () -> Void
    let onRotateCode: () -> Void
    let onClose: () -> Void

    var body: some View {
        let members = household.members ?? []

        return BLSheetContainer(
            isPresented: true,
            title: "Members",
            showScrim: true,
            onClose: onClose,
            content: {
                BLCard(isFlush: true) {
                    VStack(spacing: 0) {
                        ForEach(Array(members.enumerated()), id: \.element.userId) { index, member in
                            BLListRow(
                                label: member.displayName,
                                showDivider: index < members.count - 1
                            ) {
                                BLBadge(
                                    roleLabel(member.role),
                                    tone: member.role == .owner ? .accent : .neutral
                                )
                            }
                        }
                    }
                }

                BLCard {
                    VStack(alignment: .leading, spacing: BLSpacing.space3) {
                        Text("Invite code")
                            .blMicroLabel()

                        Text(formattedInviteCode)
                            .font(BLFont.display(size: 32, weight: .medium, tabularNumerals: true))
                            .foregroundStyle(theme.textPrimary)

                        Text("Share this 6-digit code with a parent or caregiver to join \(household.name).")
                            .blTextRole(.caption)
                            .foregroundStyle(theme.textSecondary)

                        HStack(spacing: BLSpacing.space2) {
                            BLButton("Copy code", variant: .primary, size: .md, isBlock: true, action: onCopyCode)
                            BLButton(
                                isRotatingCode ? "Updating…" : "Rotate",
                                variant: .secondary,
                                size: .md,
                                action: onRotateCode
                            )
                            .disabled(isRotatingCode)
                        }
                    }
                }
            }
        )
    }

    private func roleLabel(_ role: HouseholdRole) -> String {
        switch role {
        case .owner: "Owner"
        case .member: "Member"
        case .caregiver: "Caregiver"
        }
    }
}

// MARK: - Join Household Sheet

@MainActor
private struct JoinHouseholdSheet: View {
    @Environment(\.blTheme) private var theme

    let hasLiveSession: Bool
    let onClose: () -> Void
    let onJoin: @MainActor (String, String?) async throws -> Void

    @State private var inviteCode: String = ""
    @State private var displayName: String
    @State private var isSubmitting = false
    @State private var errorMessage: String?

    init(
        initialDisplayName: String,
        hasLiveSession: Bool,
        onClose: @escaping () -> Void,
        onJoin: @escaping @MainActor (String, String?) async throws -> Void
    ) {
        self.hasLiveSession = hasLiveSession
        self.onClose = onClose
        self.onJoin = onJoin
        _displayName = State(initialValue: initialDisplayName)
    }

    private var cleanedInviteCode: String {
        inviteCode.filter { $0.isNumber || $0.isLetter }
    }

    private var canSubmit: Bool {
        cleanedInviteCode.count == 6 && !isSubmitting
    }

    var body: some View {
        BLSheetContainer(
            isPresented: true,
            title: "Join a household",
            showScrim: true,
            onClose: onClose,
            content: {
                Text("Enter the 6-digit invite code from another parent or caregiver.")
                    .blTextRole(.callout)
                    .foregroundStyle(theme.textSecondary)

                if !hasLiveSession {
                    BLCard(tone: .sunken) {
                        Text("Sign in with Apple in Account before joining a shared household.")
                            .blTextRole(.caption)
                            .foregroundStyle(theme.textSecondary)
                    }
                }

                inviteCodeField

                BLTextField(
                    label: "Your name (optional)",
                    placeholder: "e.g. Brian",
                    text: $displayName
                )

                if let errorMessage, !errorMessage.isEmpty {
                    Text(errorMessage)
                        .blTextRole(.caption)
                        .foregroundStyle(theme.danger.ink)
                }
            },
            footer: {
                BLButton(
                    isSubmitting ? "Joining…" : "Join household",
                    variant: .primary,
                    size: .lg,
                    isBlock: true
                ) {
                    submit()
                }
                .disabled(!canSubmit)
            }
        )
    }

    @ViewBuilder
    private var inviteCodeField: some View {
        let field = BLTextField(
            label: "Invite code",
            placeholder: "482 910",
            text: $inviteCode
        )
        .autocorrectionDisabled()

        #if os(iOS)
        field
            .keyboardType(.numberPad)
            .textInputAutocapitalization(.never)
        #else
        field
        #endif
    }

    private func submit() {
        guard canSubmit else { return }
        errorMessage = nil
        isSubmitting = true
        let code = cleanedInviteCode
        let trimmedName = displayName.trimmingCharacters(in: .whitespacesAndNewlines)
        let optionalName = trimmedName.isEmpty ? nil : trimmedName

        Task { @MainActor in
            defer { isSubmitting = false }
            do {
                try await onJoin(code, optionalName)
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }
}

// MARK: - Baby Profile Editor Sheet

@MainActor
private struct BabyProfileEditorSheet: View {
    @Environment(\.blTheme) private var theme

    let onClose: () -> Void
    let onSave: @MainActor (String, Date?) async throws -> Void

    @State private var babyName: String
    @State private var hasBirthDate: Bool
    @State private var selectedBirthDate: Date
    @State private var isSaving = false
    @State private var errorMessage: String?

    init(
        initialName: String,
        initialBirthDate: Date?,
        onClose: @escaping () -> Void,
        onSave: @escaping @MainActor (String, Date?) async throws -> Void
    ) {
        self.onClose = onClose
        self.onSave = onSave
        _babyName = State(initialValue: initialName)
        _hasBirthDate = State(initialValue: initialBirthDate != nil)
        let today = Date()
        _selectedBirthDate = State(initialValue: min(initialBirthDate ?? today, today))
    }

    private var trimmedName: String {
        babyName.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var canSave: Bool {
        !trimmedName.isEmpty && !isSaving
    }

    var body: some View {
        BLSheetContainer(
            isPresented: true,
            title: "Baby profile",
            showScrim: true,
            onClose: onClose,
            content: {
                babyNameField

                VStack(alignment: .leading, spacing: BLSpacing.space3) {
                    HStack(spacing: BLSpacing.space3) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Include birth date")
                                .blTextRole(.body)
                                .foregroundStyle(theme.textPrimary)
                            Text("Used to show age on the Today screen")
                                .blTextRole(.caption)
                                .foregroundStyle(theme.textSecondary)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)

                        BLSwitch(isOn: $hasBirthDate, label: "Include birth date")
                    }

                    if hasBirthDate {
                        HStack(spacing: BLSpacing.space3) {
                            Text("Birth date")
                                .blMicroLabel()
                            Spacer()
                            DatePicker(
                                "Birth date",
                                selection: $selectedBirthDate,
                                in: ...Date(),
                                displayedComponents: .date
                            )
                            .labelsHidden()
                            .datePickerStyle(.compact)
                            .tint(theme.accent)
                        }
                        .padding(.vertical, BLSpacing.space2)
                        .padding(.horizontal, 14)
                        .frame(minHeight: 48)
                        .background(
                            RoundedRectangle(cornerRadius: BLRadius.md, style: .continuous)
                                .fill(theme.bgSurface)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: BLRadius.md, style: .continuous)
                                .strokeBorder(theme.borderStrong, lineWidth: BLSpacing.borderWidth)
                        )
                    }
                }

                if let errorMessage, !errorMessage.isEmpty {
                    Text(errorMessage)
                        .blTextRole(.caption)
                        .foregroundStyle(theme.danger.ink)
                }
            },
            footer: {
                BLButton(
                    isSaving ? "Saving…" : "Save profile",
                    variant: .primary,
                    size: .lg,
                    isBlock: true
                ) {
                    submit()
                }
                .disabled(!canSave)
            }
        )
    }

    @ViewBuilder
    private var babyNameField: some View {
        let field = BLTextField(
            label: "Baby's name",
            placeholder: "e.g. Blythe",
            text: $babyName
        )
        #if os(iOS)
        field.textInputAutocapitalization(.words)
        #else
        field
        #endif
    }

    private func submit() {
        guard canSave else { return }
        errorMessage = nil
        isSaving = true
        let name = trimmedName
        let birthDate = hasBirthDate ? selectedBirthDate : nil

        Task { @MainActor in
            defer { isSaving = false }
            do {
                try await onSave(name, birthDate)
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }
}
