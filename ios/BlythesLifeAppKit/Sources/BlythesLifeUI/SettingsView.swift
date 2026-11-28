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
    #if DEBUG
    @Environment(\.duoLayout) private var duoLayout
    #endif

    private let store: BlythesLifeStore

    @State private var isBabyProfileSheetOpen = false
    @State private var isScheduleSheetOpen = false
    @State private var isFeedMealSheetOpen = false
    @State private var isPumpNotificationsSheetOpen = false
    @State private var isMembersSheetOpen = false
    @State private var isCreateInviteSheetOpen = false
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
                            feedMealScheduleGroup
                            loggingGroup
                            notificationsGroup
                            #if DEBUG
                            posturePreviewGroup
                            #endif
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
                                feedMealScheduleGroup
                                loggingGroup
                                notificationsGroup
                                #if DEBUG
                                posturePreviewGroup
                                #endif
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

            if isFeedMealSheetOpen {
                FeedMealScheduleEditorSheet(
                    initialConfig: store.profile.scheduleConfig,
                    onClose: { isFeedMealSheetOpen = false },
                    onSave: { updated in
                        store.updateScheduleConfig(updated)
                        isFeedMealSheetOpen = false
                    }
                )
                .zIndex(10)
            }

            if isPumpNotificationsSheetOpen {
                PumpNotificationsEditorSheet(
                    initialSettings: store.pumpNotificationSettings,
                    onClose: { isPumpNotificationsSheetOpen = false },
                    onSave: { updated in
                        await store.updatePumpNotificationSettings(updated)
                        store.showInfoToast("Pump reminders updated")
                    }
                )
                .zIndex(10)
            }

            if isMembersSheetOpen {
                HouseholdMembersSheet(
                    household: store.household,
                    currentUserId: store.currentUserId,
                    isCurrentUserOwner: store.isCurrentUserHouseholdOwner,
                    canManageInvites: canManageInvites,
                    onRemoveMember: { userId in
                        try await store.removeHouseholdMemberAsync(userId: userId)
                    },
                    onOpenCreateInvite: {
                        isMembersSheetOpen = false
                        isCreateInviteSheetOpen = true
                    },
                    onShowError: { message in
                        store.showInfoToast(message)
                    },
                    onClose: { isMembersSheetOpen = false }
                )
                .zIndex(10)
            }

            if isCreateInviteSheetOpen {
                CreateInviteSheet(
                    onClose: { isCreateInviteSheetOpen = false },
                    onCreate: { label, role in
                        try await store.createHouseholdInviteAsync(
                            label: label,
                            role: role,
                            ttlHours: 24
                        )
                    },
                    onCopyCode: { code in
                        copyInviteCode(code)
                    }
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
        .task {
            await store.refreshPumpNotificationAuthorization()
            if store.hasLiveSession {
                await store.refreshHouseholdAsync()
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
            BabyProfileSettingsCard(
                store: store,
                formattedBirthDate: formattedBirthDateDisplay,
                onTap: { isBabyProfileSheetOpen = true }
            )
        }
    }

    private var napScheduleGroup: some View {
        let config = store.profile.scheduleConfig
        let windows = config.wakeWindowsMinutes.isEmpty
            ? ScheduleConfig.defaultWakeWindowsMinutes
            : config.wakeWindowsMinutes

        return settingsGroup(title: "Nap & bedtime schedule") {
            BLCard(isFlush: true) {
                VStack(spacing: 0) {
                    BLListRow(
                        label: "Naps per day",
                        value: "\(windows.count)",
                        showsChevron: true,
                        onTap: { isScheduleSheetOpen = true }
                    )
                    ForEach(Array(windows.enumerated()), id: \.offset) { index, minutes in
                        BLListRow(
                            label: "Awake before nap \(index + 1)",
                            value: FormattingHelpers.formatWakeWindowFraction(minutes: minutes),
                            showsChevron: true,
                            onTap: { isScheduleSheetOpen = true }
                        )
                    }
                    BLListRow(
                        label: "Awake before bedtime",
                        value: FormattingHelpers.formatWakeWindowFraction(
                            minutes: config.bedtimeWakeWindowMinutes
                        ),
                        showsChevron: true,
                        onTap: { isScheduleSheetOpen = true }
                    )
                    BLListRow(
                        label: "Target bedtime",
                        value: FormattingHelpers.formatMinutesFromMidnight(
                            config.targetBedtimeMinutesFromMidnight
                        ),
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

    private var feedMealScheduleGroup: some View {
        let config = store.profile.scheduleConfig
        let mealTargets = config.mealTargetMinutesFromMidnight.isEmpty
            ? ScheduleConfig.defaultMealTargetMinutesFromMidnight
            : config.mealTargetMinutesFromMidnight.sorted()

        return settingsGroup(title: "Feed & meal sweet spots") {
            BLCard(isFlush: true) {
                VStack(spacing: 0) {
                    BLListRow(
                        label: "Time between feeds",
                        value: FormattingHelpers.formatWakeWindowFraction(
                            minutes: config.feedingIntervalMinutes
                        ),
                        showsChevron: true,
                        onTap: { isFeedMealSheetOpen = true }
                    )
                    BLListRow(
                        label: "Solid meals per day",
                        value: "\(mealTargets.count)",
                        showsChevron: true,
                        onTap: { isFeedMealSheetOpen = true }
                    )
                    ForEach(Array(mealTargets.enumerated()), id: \.offset) { _, mins in
                        BLListRow(
                            label: FormattingHelpers.formatMealSlot(
                                MealSlotClassifier.classify(minutesFromMidnight: mins)
                            ),
                            value: FormattingHelpers.formatMinutesFromMidnight(mins),
                            showsChevron: true,
                            onTap: { isFeedMealSheetOpen = true }
                        )
                    }
                    BLListRow(
                        label: "Spacing after a feed",
                        value: config.minMinutesAfterFeedForMeal == 0
                            ? "Off"
                            : "\(config.minMinutesAfterFeedForMeal)m",
                        showsChevron: true,
                        showDivider: false,
                        onTap: { isFeedMealSheetOpen = true }
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

    private var notificationsGroup: some View {
        settingsGroup(title: "Notifications") {
            PumpNotificationSettingsSection(
                store: store,
                onOpenEditor: { isPumpNotificationsSheetOpen = true }
            )
        }
    }

    #if DEBUG
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
    #endif

    private var householdGroup: some View {
        settingsGroup(title: "Household") {
            HouseholdSettingsSection(
                store: store,
                canManageInvites: canManageInvites,
                onOpenMembers: { isMembersSheetOpen = true },
                onOpenCreateInvite: { isCreateInviteSheetOpen = true },
                onOpenJoinHousehold: { isJoinHouseholdSheetOpen = true },
                onCopyCode: copyInviteCode
            )
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

    #if DEBUG
    private var activePostureDescription: String {
        switch duoLayout.posture {
        case .compactPhone: "iPhone"
        case .duoFolded: "iPhone Duo · Folded"
        case .duoUnfolded: "iPhone Duo · Unfolded"
        case .duoTabletop: "iPhone Duo · Tabletop"
        case .iPadRegular: "iPad"
        }
    }
    #endif

    private var canManageInvites: Bool {
        let role = store.household.role
            ?? store.household.members?.first(where: { $0.userId == store.currentUserId })?.role
            ?? .owner
        return role == .owner || role == .member
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

    private func copyInviteCode(_ rawCode: String) {
        let code = FormattingHelpers.formatInviteCode(rawCode)
        #if canImport(UIKit)
        UIPasteboard.general.string = code
        #elseif canImport(AppKit)
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(code, forType: .string)
        #endif
        store.showInfoToast("Invite code copied · \(code)")
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

// MARK: - Clock-Isolated Settings Sections

@MainActor
private struct BabyProfileSettingsCard: View {
    let store: BlythesLifeStore
    let formattedBirthDate: String
    let onTap: () -> Void

    var body: some View {
        let ageLabel = store.profileAgeLabel
        BLCard(isFlush: true) {
            VStack(spacing: 0) {
                BLListRow(
                    label: "Name",
                    value: store.profile.displayName,
                    showsChevron: true,
                    onTap: onTap
                )
                BLListRow(
                    label: "Birth date",
                    detail: ageLabel.isEmpty ? nil : ageLabel,
                    value: formattedBirthDate,
                    showsChevron: true,
                    showDivider: false,
                    onTap: onTap
                )
            }
        }
    }
}

@MainActor
private struct PumpNotificationSettingsSection: View {
    @Environment(\.openURL) private var openURL

    let store: BlythesLifeStore
    let onOpenEditor: () -> Void

    @State private var isUpdatingToggle = false

    var body: some View {
        let settings = store.pumpNotificationSettings
        let authStatus = store.pumpNotificationAuthStatus
        #if os(iOS) && canImport(UIKit)
        let showsOpenSettingsRow = authStatus == .denied
        #else
        let showsOpenSettingsRow = false
        #endif

        let enabledBinding = Binding<Bool>(
            get: { settings.isEnabled },
            set: { newValue in
                guard !isUpdatingToggle, newValue != store.pumpNotificationSettings.isEnabled else { return }
                isUpdatingToggle = true
                var updated = store.pumpNotificationSettings
                updated.isEnabled = newValue
                Task { @MainActor in
                    defer { isUpdatingToggle = false }
                    await store.updatePumpNotificationSettings(updated)
                    if newValue && store.pumpNotificationAuthStatus == .denied {
                        store.showInfoToast("Allow notifications in iOS Settings to enable pump reminders")
                    }
                }
            }
        )

        BLCard(isFlush: true) {
            VStack(spacing: 0) {
                BLListRow(
                    label: "Pump reminders",
                    detail: toggleDetail(settings: settings, authStatus: authStatus),
                    showDivider: showsOpenSettingsRow || settings.isEnabled
                ) {
                    BLSwitch(isOn: enabledBinding, label: "Pump reminders")
                        .disabled(isUpdatingToggle)
                }

                #if os(iOS) && canImport(UIKit)
                if showsOpenSettingsRow {
                    BLListRow(
                        label: "Open iOS Settings",
                        showDivider: settings.isEnabled
                    ) {
                        BLButton("Open", variant: .secondary, size: .sm) {
                            if let url = URL(string: UIApplication.openSettingsURLString) {
                                openURL(url)
                            }
                        }
                    }
                }
                #endif

                if settings.isEnabled {
                    BLListRow(
                        label: "Remind every",
                        value: FormattingHelpers.formatWakeWindowFraction(minutes: settings.intervalMinutes),
                        showsChevron: true,
                        onTap: onOpenEditor
                    )
                    BLListRow(
                        label: "Timer target alert",
                        value: settings.timerAlertMinutes.map { "\($0)m" } ?? "Off",
                        showsChevron: true,
                        onTap: onOpenEditor
                    )
                    BLListRow(
                        label: "Quiet hours",
                        value: settings.quietHoursEnabled
                            ? "\(FormattingHelpers.formatMinutesFromMidnight(settings.quietStartMinutesFromMidnight)) – \(FormattingHelpers.formatMinutesFromMidnight(settings.quietEndMinutesFromMidnight))"
                            : "Off",
                        showsChevron: true,
                        showDivider: false,
                        onTap: onOpenEditor
                    )
                }
            }
        }
    }

    private func toggleDetail(
        settings: PumpNotificationSettings,
        authStatus: PumpNotificationAuthorizationStatus
    ) -> String {
        if authStatus == .denied {
            return "Notifications are off in iOS Settings"
        }
        if settings.isEnabled {
            if let nextDate = store.nextScheduledPumpReminderDate {
                return "Next reminder · \(FormattingHelpers.formatClock(nextDate, timeZone: store.profileTimeZone))"
            }
            if store.activePump != nil {
                return "Timer active · next reminder schedules after finish"
            }
            return "Starts after your next pump"
        }
        return "This device only · remind when it is time to pump"
    }
}

@MainActor
private struct HouseholdSettingsSection: View {
    private enum JoinRequestAction: Equatable {
        case approving
        case declining
    }

    @Environment(\.blTheme) private var theme

    let store: BlythesLifeStore
    let canManageInvites: Bool
    let onOpenMembers: () -> Void
    let onOpenCreateInvite: () -> Void
    let onOpenJoinHousehold: () -> Void
    let onCopyCode: (String) -> Void

    @State private var busyJoinRequests: [UUID: JoinRequestAction] = [:]
    @State private var revokingInviteIds: Set<UUID> = []

    var body: some View {
        let memberCount = store.household.members?.count ?? 1
        let pendingRequests = store.isCurrentUserHouseholdOwner ? store.pendingHouseholdJoinRequests : []
        let activeInvites = canManageInvites ? store.activeHouseholdInvites : []

        VStack(alignment: .leading, spacing: BLSpacing.space2) {
            if !pendingRequests.isEmpty {
                BLCard(tone: .accent, isFlush: true) {
                    VStack(spacing: 0) {
                        ForEach(Array(pendingRequests.enumerated()), id: \.element.id) { index, req in
                            let action = busyJoinRequests[req.id]
                            let isBusy = action != nil

                            VStack(alignment: .leading, spacing: BLSpacing.space3) {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("\(req.displayName) wants to join")
                                        .blTextRole(.body)
                                        .foregroundStyle(theme.textPrimary)
                                    Text(householdRoleLabel(req.requestedRole))
                                        .blTextRole(.caption)
                                        .foregroundStyle(theme.textSecondary)
                                }

                                HStack(spacing: BLSpacing.space2) {
                                    BLButton(
                                        action == .approving ? "Accepting…" : "Accept",
                                        variant: .primary,
                                        size: .sm
                                    ) {
                                        resolveJoinRequest(req.id, approve: true)
                                    }
                                    .disabled(isBusy)

                                    BLButton(
                                        action == .declining ? "Declining…" : "Decline",
                                        variant: .secondary,
                                        size: .sm
                                    ) {
                                        resolveJoinRequest(req.id, approve: false)
                                    }
                                    .disabled(isBusy)
                                }
                            }
                            .padding(.vertical, BLSpacing.space3)
                            .padding(.horizontal, BLSpacing.space4)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .overlay(alignment: .bottom) {
                                if index < pendingRequests.count - 1 {
                                    Rectangle()
                                        .fill(theme.accentBorder.opacity(0.45))
                                        .frame(height: BLSpacing.borderWidth)
                                }
                            }
                        }
                    }
                }
            }

            BLCard(isFlush: true) {
                VStack(spacing: 0) {
                    BLListRow(
                        icon: BLSymbol.members,
                        label: "Members",
                        value: "\(memberCount)",
                        showsChevron: true,
                        onTap: onOpenMembers
                    )

                    if canManageInvites {
                        BLListRow(
                            icon: BLSymbol.inviteKey,
                            label: "One-time invites",
                            detail: activeInvites.isEmpty ? "None active" : "\(activeInvites.count) active",
                            showDivider: true
                        ) {
                            BLButton(
                                "Create invite",
                                variant: .secondary,
                                size: .sm,
                                action: onOpenCreateInvite
                            )
                        }

                        ForEach(activeInvites) { invite in
                            let isRevoking = revokingInviteIds.contains(invite.id)
                            activeInviteRow(invite: invite, isRevoking: isRevoking)
                        }
                    }

                    BLListRow(
                        icon: "person.badge.plus",
                        label: "Join a household",
                        detail: "Enter a one-time invite code",
                        showsChevron: true,
                        showDivider: false,
                        onTap: onOpenJoinHousehold
                    )
                }
            }
        }
    }

    private func activeInviteRow(invite: HouseholdInviteDTO, isRevoking: Bool) -> some View {
        let formattedCode = FormattingHelpers.formatInviteCode(invite.code)
        let detail = inviteDetailText(invite)

        return HStack(alignment: .center, spacing: BLSpacing.space2) {
            VStack(alignment: .leading, spacing: 2) {
                Text(formattedCode)
                    .font(BLFont.ui(size: 16, weight: .semibold, tabularNumerals: true))
                    .foregroundStyle(theme.textPrimary)
                    .lineLimit(1)

                Text(detail)
                    .blTextRole(.caption)
                    .foregroundStyle(theme.textSecondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            BLButton("Copy", variant: .secondary, size: .sm) {
                onCopyCode(invite.code)
            }
            .disabled(isRevoking)

            BLButton(
                isRevoking ? "Revoking…" : "Revoke",
                variant: .danger,
                size: .sm
            ) {
                revokeInvite(invite.id)
            }
            .disabled(isRevoking)
        }
        .padding(.vertical, BLSpacing.space2)
        .padding(.horizontal, BLSpacing.space4)
        .frame(minHeight: 52)
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(theme.borderHairline)
                .frame(height: BLSpacing.borderWidth)
        }
    }

    private func inviteDetailText(_ invite: HouseholdInviteDTO) -> String {
        var parts: [String] = []
        if let label = invite.label?.trimmingCharacters(in: .whitespacesAndNewlines), !label.isEmpty {
            parts.append(label)
        }
        parts.append(householdRoleLabel(invite.role))
        parts.append(FormattingHelpers.formatExpiryCountdown(invite.expiresAt, asOf: store.now))
        return parts.joined(separator: " · ")
    }

    private func resolveJoinRequest(_ requestId: UUID, approve: Bool) {
        guard busyJoinRequests[requestId] == nil else { return }
        busyJoinRequests[requestId] = approve ? .approving : .declining
        Task { @MainActor in
            defer { busyJoinRequests.removeValue(forKey: requestId) }
            do {
                if approve {
                    try await store.approveJoinRequestAsync(requestId: requestId)
                } else {
                    try await store.declineJoinRequestAsync(requestId: requestId)
                }
            } catch {
                store.showInfoToast(error.localizedDescription)
            }
        }
    }

    private func revokeInvite(_ inviteId: UUID) {
        guard !revokingInviteIds.contains(inviteId) else { return }
        revokingInviteIds.insert(inviteId)
        Task { @MainActor in
            defer { revokingInviteIds.remove(inviteId) }
            do {
                try await store.revokeHouseholdInviteAsync(inviteId: inviteId)
            } catch {
                store.showInfoToast(error.localizedDescription)
            }
        }
    }
}

private func householdRoleLabel(_ role: HouseholdRole) -> String {
    switch role {
    case .owner: "Owner"
    case .member: "Member"
    case .caregiver: "Caregiver"
    }
}

// MARK: - Nap & Bedtime Schedule Editor Sheet

@MainActor
private struct NapScheduleEditorSheet: View {
    @Environment(\.blTheme) private var theme

    let onClose: () -> Void
    let onSave: (ScheduleConfig) -> Void

    @State private var wakeWindows: [Int]
    @State private var bedtimeWakeWindow: Int
    @State private var targetBedtime: Int
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
        let source = initialConfig.wakeWindowsMinutes.isEmpty
            ? ScheduleConfig.defaultWakeWindowsMinutes
            : initialConfig.wakeWindowsMinutes
        let clamped = Array(source.prefix(4)).map { min(max($0, 45), 420) }
        _wakeWindows = State(initialValue: clamped)
        _bedtimeWakeWindow = State(initialValue: min(max(initialConfig.bedtimeWakeWindowMinutes, 90), 420))
        _targetBedtime = State(initialValue: min(max(initialConfig.targetBedtimeMinutesFromMidnight, 1080), 1320))
        _napCap = State(initialValue: min(max(initialConfig.napCapMinutes, 30), 240))
        _backupCutoff = State(initialValue: min(max(initialConfig.backupCatnapCutoffMinutesFromMidnight, 840), 1140))
    }

    private var napCountBinding: Binding<Int> {
        Binding(
            get: { min(max(wakeWindows.count, 1), 4) },
            set: { newCount in
                let targetCount = min(max(newCount, 1), 4)
                let oldCount = wakeWindows.count
                guard targetCount != oldCount else { return }
                if targetCount < oldCount {
                    wakeWindows = Array(wakeWindows.prefix(targetCount))
                } else {
                    let defaults = ScheduleConfig.defaultWakeWindows(forNapCount: targetCount)
                    var next = wakeWindows
                    for index in oldCount ..< targetCount {
                        if index < defaults.count {
                            next.append(defaults[index])
                        } else {
                            let fallback = min(420, (next.last ?? 150) + 30)
                            next.append(fallback)
                        }
                    }
                    wakeWindows = next
                }
                bedtimeWakeWindow = ScheduleConfig.defaultBedtimeWakeWindow(forNapCount: targetCount)
            }
        )
    }

    var body: some View {
        BLSheetContainer(
            isPresented: true,
            title: "Nap & bedtime schedule",
            showScrim: true,
            onClose: onClose,
            icon: {
                BLEventIcon(kind: .sleep, size: .md)
            },
            content: {
                VStack(alignment: .leading, spacing: BLSpacing.space2) {
                    Text("Naps per day")
                        .blMicroLabel()

                    BLSegmentedControl(
                        options: [1, 2, 3, 4],
                        selection: napCountBinding,
                        size: .md,
                        isBlock: true
                    ) { "\($0)" }

                    HStack {
                        Spacer()
                        BLButton(
                            "Reset to typical for \(wakeWindows.count) \(wakeWindows.count == 1 ? "nap" : "naps")",
                            variant: .ghost,
                            size: .sm
                        ) {
                            wakeWindows = ScheduleConfig.defaultWakeWindows(forNapCount: wakeWindows.count)
                            bedtimeWakeWindow = ScheduleConfig.defaultBedtimeWakeWindow(forNapCount: wakeWindows.count)
                        }
                    }
                }

                ForEach(Array(wakeWindows.indices), id: \.self) { index in
                    let minutes = wakeWindows[index]
                    ScheduleStepperRow(
                        label: "Awake before nap \(index + 1)",
                        value: FormattingHelpers.formatWakeWindowFraction(minutes: minutes),
                        canDecrement: minutes > 45,
                        canIncrement: minutes < 420,
                        onDecrement: {
                            guard index < wakeWindows.count else { return }
                            wakeWindows[index] = max(45, wakeWindows[index] - 15)
                        },
                        onIncrement: {
                            guard index < wakeWindows.count else { return }
                            wakeWindows[index] = min(420, wakeWindows[index] + 15)
                        }
                    )
                }

                ScheduleStepperRow(
                    label: "Awake before bedtime",
                    value: FormattingHelpers.formatWakeWindowFraction(minutes: bedtimeWakeWindow),
                    canDecrement: bedtimeWakeWindow > 90,
                    canIncrement: bedtimeWakeWindow < 420,
                    onDecrement: { bedtimeWakeWindow = max(90, bedtimeWakeWindow - 15) },
                    onIncrement: { bedtimeWakeWindow = min(420, bedtimeWakeWindow + 15) }
                )

                VStack(alignment: .leading, spacing: BLSpacing.space1) {
                    ScheduleStepperRow(
                        label: "Target bedtime",
                        value: FormattingHelpers.formatMinutesFromMidnight(targetBedtime),
                        canDecrement: targetBedtime > 1080,
                        canIncrement: targetBedtime < 1320,
                        onDecrement: { targetBedtime = max(1080, targetBedtime - 15) },
                        onIncrement: { targetBedtime = min(1320, targetBedtime + 15) }
                    )

                    Text("Sleep within 45 min of target bedtime counts as night sleep.")
                        .blTextRole(.caption)
                        .foregroundStyle(theme.textSecondary)
                }

                ScheduleStepperRow(
                    label: "Nap cap",
                    value: FormattingHelpers.formatWakeWindowFraction(minutes: napCap),
                    canDecrement: napCap > 30,
                    canIncrement: napCap < 240,
                    onDecrement: { napCap = max(30, napCap - 15) },
                    onIncrement: { napCap = min(240, napCap + 15) }
                )

                ScheduleStepperRow(
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
                    updated.wakeWindowsMinutes = wakeWindows
                    updated.bedtimeWakeWindowMinutes = bedtimeWakeWindow
                    updated.targetBedtimeMinutesFromMidnight = targetBedtime
                    updated.napCapMinutes = napCap
                    updated.backupCatnapCutoffMinutesFromMidnight = backupCutoff
                    onSave(updated)
                }
            }
        )
    }
}

// MARK: - Feed & Meal Sweet Spots Editor Sheet

@MainActor
private struct FeedMealScheduleEditorSheet: View {
    @Environment(\.blTheme) private var theme

    let onClose: () -> Void
    let onSave: (ScheduleConfig) -> Void

    @State private var feedingInterval: Int
    @State private var mealTargets: [Int]
    @State private var minSpacingAfterFeed: Int
    private let baseConfig: ScheduleConfig

    init(
        initialConfig: ScheduleConfig,
        onClose: @escaping () -> Void,
        onSave: @escaping (ScheduleConfig) -> Void
    ) {
        self.baseConfig = initialConfig
        self.onClose = onClose
        self.onSave = onSave
        _feedingInterval = State(initialValue: min(max(initialConfig.feedingIntervalMinutes, 90), 300))
        let sourceMeals = initialConfig.mealTargetMinutesFromMidnight.isEmpty
            ? ScheduleConfig.defaultMealTargetMinutesFromMidnight
            : initialConfig.mealTargetMinutesFromMidnight.sorted()
        let clampedMeals = Array(sourceMeals.prefix(3)).map { min(max($0, 360), 1200) }
        _mealTargets = State(initialValue: clampedMeals)
        _minSpacingAfterFeed = State(initialValue: min(max(initialConfig.minMinutesAfterFeedForMeal, 0), 120))
    }

    private var mealCountBinding: Binding<Int> {
        Binding(
            get: { min(max(mealTargets.count, 1), 3) },
            set: { newCount in
                let targetCount = min(max(newCount, 1), 3)
                guard targetCount != mealTargets.count else { return }
                mealTargets = ScheduleConfig.defaultMealTargets(forMealCount: targetCount)
            }
        )
    }

    var body: some View {
        BLSheetContainer(
            isPresented: true,
            title: "Feed & meal sweet spots",
            showScrim: true,
            onClose: onClose,
            icon: {
                BLEventIcon(kind: .feeding, size: .md)
            },
            content: {
                VStack(alignment: .leading, spacing: BLSpacing.space1) {
                    ScheduleStepperRow(
                        label: "Time between feeds",
                        value: FormattingHelpers.formatWakeWindowFraction(minutes: feedingInterval),
                        canDecrement: feedingInterval > 90,
                        canIncrement: feedingInterval < 300,
                        onDecrement: { feedingInterval = max(90, feedingInterval - 15) },
                        onIncrement: { feedingInterval = min(300, feedingInterval + 15) }
                    )

                    Text("Evening feeds cap 30 min before target bedtime.")
                        .blTextRole(.caption)
                        .foregroundStyle(theme.textSecondary)
                }

                VStack(alignment: .leading, spacing: BLSpacing.space2) {
                    Text("Solid meals per day")
                        .blMicroLabel()

                    BLSegmentedControl(
                        options: [1, 2, 3],
                        selection: mealCountBinding,
                        size: .md,
                        isBlock: true
                    ) { "\($0)" }

                    HStack {
                        Spacer()
                        BLButton(
                            "Reset to typical for \(mealTargets.count) \(mealTargets.count == 1 ? "meal" : "meals")",
                            variant: .ghost,
                            size: .sm
                        ) {
                            mealTargets = ScheduleConfig.defaultMealTargets(forMealCount: mealTargets.count)
                        }
                    }
                }

                ForEach(Array(mealTargets.indices), id: \.self) { index in
                    let minutes = mealTargets[index]
                    let slotLabel = FormattingHelpers.formatMealSlot(
                        MealSlotClassifier.classify(minutesFromMidnight: minutes)
                    )
                    ScheduleStepperRow(
                        label: slotLabel,
                        value: FormattingHelpers.formatMinutesFromMidnight(minutes),
                        canDecrement: minutes > 360,
                        canIncrement: minutes < 1200,
                        onDecrement: {
                            guard index < mealTargets.count else { return }
                            mealTargets[index] = max(360, mealTargets[index] - 15)
                        },
                        onIncrement: {
                            guard index < mealTargets.count else { return }
                            mealTargets[index] = min(1200, mealTargets[index] + 15)
                        }
                    )
                }

                VStack(alignment: .leading, spacing: BLSpacing.space1) {
                    ScheduleStepperRow(
                        label: "Spacing after a feed",
                        value: minSpacingAfterFeed == 0 ? "Off" : "\(minSpacingAfterFeed)m",
                        canDecrement: minSpacingAfterFeed > 0,
                        canIncrement: minSpacingAfterFeed < 120,
                        onDecrement: { minSpacingAfterFeed = max(0, minSpacingAfterFeed - 15) },
                        onIncrement: { minSpacingAfterFeed = min(120, minSpacingAfterFeed + 15) }
                    )

                    Text("Gently nudges a meal window right after a bottle or nursing session.")
                        .blTextRole(.caption)
                        .foregroundStyle(theme.textSecondary)
                }
            },
            footer: {
                BLButton("Save rhythm", variant: .primary, size: .lg, isBlock: true) {
                    var updated = baseConfig
                    updated.feedingIntervalMinutes = feedingInterval
                    updated.mealTargetMinutesFromMidnight = mealTargets.sorted()
                    updated.minMinutesAfterFeedForMeal = minSpacingAfterFeed
                    onSave(updated)
                }
            }
        )
    }
}

// MARK: - Pump Reminders Editor Sheet

@MainActor
private struct PumpNotificationsEditorSheet: View {
    private static let intervalOptions: [Int] = [120, 150, 180, 210, 240, 300, 360]
    private static let timerAlertOptions: [Int?] = [nil, 15, 20, 25, 30]

    @Environment(\.blTheme) private var theme

    let onClose: () -> Void
    let onSave: @MainActor (PumpNotificationSettings) async -> Void

    @State private var intervalMinutes: Int
    @State private var timerAlertMinutes: Int?
    @State private var quietHoursEnabled: Bool
    @State private var quietStartDate: Date
    @State private var quietEndDate: Date
    @State private var isSaving = false
    private let baseSettings: PumpNotificationSettings

    init(
        initialSettings: PumpNotificationSettings,
        onClose: @escaping () -> Void,
        onSave: @escaping @MainActor (PumpNotificationSettings) async -> Void
    ) {
        self.baseSettings = initialSettings
        self.onClose = onClose
        self.onSave = onSave
        _intervalMinutes = State(initialValue: initialSettings.intervalMinutes)
        _timerAlertMinutes = State(initialValue: initialSettings.timerAlertMinutes)
        _quietHoursEnabled = State(initialValue: initialSettings.quietHoursEnabled)
        _quietStartDate = State(
            initialValue: Self.dateFromMinutesFromMidnight(initialSettings.quietStartMinutesFromMidnight)
        )
        _quietEndDate = State(
            initialValue: Self.dateFromMinutesFromMidnight(initialSettings.quietEndMinutesFromMidnight)
        )
    }

    var body: some View {
        BLSheetContainer(
            isPresented: true,
            title: "Pump reminders",
            showScrim: true,
            onClose: onClose,
            icon: {
                BLEventIcon(kind: .pump, size: .md)
            },
            content: {
                VStack(alignment: .leading, spacing: BLSpacing.space2) {
                    Text("Remind every")
                        .blMicroLabel()

                    BLFlowLayout(horizontalSpacing: BLSpacing.space2, verticalSpacing: BLSpacing.space2) {
                        ForEach(Self.intervalOptions, id: \.self) { minutes in
                            BLChip(
                                FormattingHelpers.formatWakeWindowFraction(minutes: minutes),
                                isSelected: intervalMinutes == minutes
                            ) {
                                intervalMinutes = minutes
                            }
                        }
                    }
                }

                VStack(alignment: .leading, spacing: BLSpacing.space2) {
                    Text("Timer target alert")
                        .blMicroLabel()

                    BLFlowLayout(horizontalSpacing: BLSpacing.space2, verticalSpacing: BLSpacing.space2) {
                        ForEach(Self.timerAlertOptions, id: \.self) { option in
                            BLChip(
                                option.map { "\($0)m" } ?? "Off",
                                isSelected: timerAlertMinutes == option
                            ) {
                                timerAlertMinutes = option
                            }
                        }
                    }

                    Text("Alerts when a live pump timer reaches this length.")
                        .blTextRole(.caption)
                        .foregroundStyle(theme.textSecondary)
                }

                VStack(alignment: .leading, spacing: BLSpacing.space3) {
                    Text("Quiet hours")
                        .blMicroLabel()

                    HStack(spacing: BLSpacing.space3) {
                        Text("Pause overnight")
                            .blTextRole(.body)
                            .foregroundStyle(theme.textPrimary)
                            .frame(maxWidth: .infinity, alignment: .leading)

                        BLSwitch(isOn: $quietHoursEnabled, label: "Pause overnight")
                    }

                    if quietHoursEnabled {
                        HStack(spacing: BLSpacing.space3) {
                            BLTimeField(label: "Start", date: $quietStartDate)
                                .frame(maxWidth: .infinity, alignment: .leading)
                            BLTimeField(label: "End", date: $quietEndDate)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }

                    Text("Reminders during quiet hours wait until morning.")
                        .blTextRole(.caption)
                        .foregroundStyle(theme.textSecondary)
                }
            },
            footer: {
                BLButton(
                    isSaving ? "Saving…" : "Save reminders",
                    variant: .primary,
                    size: .lg,
                    isBlock: true
                ) {
                    save()
                }
                .disabled(isSaving)
            }
        )
    }

    private func save() {
        guard !isSaving else { return }
        isSaving = true
        var updated = baseSettings
        updated.intervalMinutes = intervalMinutes
        updated.timerAlertMinutes = timerAlertMinutes
        updated.quietHoursEnabled = quietHoursEnabled
        updated.quietStartMinutesFromMidnight = Self.minutesFromMidnight(from: quietStartDate)
        updated.quietEndMinutesFromMidnight = Self.minutesFromMidnight(from: quietEndDate)

        Task { @MainActor in
            defer { isSaving = false }
            await onSave(updated)
            onClose()
        }
    }

    private static func dateFromMinutesFromMidnight(_ rawMinutes: Int) -> Date {
        let normalized = ((rawMinutes % 1440) + 1440) % 1440
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = .current
        let components = DateComponents(
            year: 2026,
            month: 1,
            day: 15,
            hour: normalized / 60,
            minute: normalized % 60
        )
        return calendar.date(from: components) ?? Date(timeIntervalSinceReferenceDate: 0)
    }

    private static func minutesFromMidnight(from date: Date) -> Int {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = .current
        let components = calendar.dateComponents([.hour, .minute], from: date)
        let hour = components.hour ?? 0
        let minute = components.minute ?? 0
        return ((hour * 60 + minute) % 1440 + 1440) % 1440
    }
}

@MainActor
private struct ScheduleStepperRow: View {
    @Environment(\.blTheme) private var theme

    let label: String
    let value: String
    let canDecrement: Bool
    let canIncrement: Bool
    let onDecrement: () -> Void
    let onIncrement: () -> Void

    var body: some View {
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

@MainActor
private struct HouseholdMembersSheet: View {
    let household: HouseholdDTO
    let currentUserId: UUID
    let isCurrentUserOwner: Bool
    let canManageInvites: Bool
    let onRemoveMember: @MainActor (UUID) async throws -> Void
    let onOpenCreateInvite: () -> Void
    let onShowError: (String) -> Void
    let onClose: () -> Void

    @State private var memberPendingRemoval: HouseholdMemberDTO?
    @State private var removingUserIds: Set<UUID> = []

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
                            let canRemove = isCurrentUserOwner
                                && member.userId != currentUserId
                                && member.role != .owner
                            let isRemoving = removingUserIds.contains(member.userId)

                            BLListRow(
                                label: member.displayName,
                                showDivider: index < members.count - 1
                            ) {
                                HStack(spacing: BLSpacing.space2) {
                                    BLBadge(
                                        householdRoleLabel(member.role),
                                        tone: member.role == .owner ? .accent : .neutral
                                    )

                                    if canRemove {
                                        BLButton(
                                            isRemoving ? "Removing…" : "Remove",
                                            variant: .danger,
                                            size: .sm
                                        ) {
                                            memberPendingRemoval = member
                                        }
                                        .disabled(isRemoving)
                                    }
                                }
                            }
                        }
                    }
                }

                if canManageInvites {
                    BLButton(
                        "Create one-time invite",
                        variant: .secondary,
                        size: .md,
                        isBlock: true,
                        action: onOpenCreateInvite
                    )
                }
            }
        )
        .alert(
            "Remove member",
            isPresented: Binding(
                get: { memberPendingRemoval != nil },
                set: { if !$0 { memberPendingRemoval = nil } }
            ),
            presenting: memberPendingRemoval
        ) { member in
            Button("Cancel", role: .cancel) {
                memberPendingRemoval = nil
            }
            Button("Remove", role: .destructive) {
                confirmRemove(member)
            }
        } message: { member in
            Text("Remove \(member.displayName) from \(household.name)? They will lose access on their devices.")
        }
    }

    private func confirmRemove(_ member: HouseholdMemberDTO) {
        guard !removingUserIds.contains(member.userId) else { return }
        removingUserIds.insert(member.userId)
        memberPendingRemoval = nil
        Task { @MainActor in
            defer { removingUserIds.remove(member.userId) }
            do {
                try await onRemoveMember(member.userId)
            } catch {
                onShowError(error.localizedDescription)
            }
        }
    }
}

// MARK: - Create One-Time Invite Sheet

@MainActor
private struct CreateInviteSheet: View {
    @Environment(\.blTheme) private var theme

    let onClose: () -> Void
    let onCreate: @MainActor (String?, HouseholdRole) async throws -> HouseholdInviteDTO
    let onCopyCode: (String) -> Void

    @State private var label: String = ""
    @State private var selectedRole: HouseholdRole = .member
    @State private var isCreating = false
    @State private var errorMessage: String?
    @State private var createdInvite: HouseholdInviteDTO?

    var body: some View {
        BLSheetContainer(
            isPresented: true,
            title: createdInvite == nil ? "Create one-time invite" : "One-time invite",
            showScrim: true,
            onClose: onClose,
            content: {
                if let created = createdInvite {
                    BLCard {
                        VStack(alignment: .leading, spacing: BLSpacing.space3) {
                            Text("Invite code")
                                .blMicroLabel()

                            Text(FormattingHelpers.formatInviteCode(created.code))
                                .font(BLFont.display(size: 34, weight: .medium, tabularNumerals: true))
                                .foregroundStyle(theme.textPrimary)
                                .textSelection(.enabled)

                            Text(createdDetail(created))
                                .blTextRole(.caption)
                                .foregroundStyle(theme.textSecondary)

                            Text("Once they enter this code, tap Accept to let them into the household.")
                                .blTextRole(.caption)
                                .foregroundStyle(theme.textSecondary)
                        }
                    }
                } else {
                    labelField

                    VStack(alignment: .leading, spacing: BLSpacing.space2) {
                        Text("Role")
                            .blMicroLabel()

                        BLSegmentedControl(
                            options: [HouseholdRole.member, .caregiver],
                            selection: $selectedRole,
                            size: .md,
                            isBlock: true
                        ) { role in
                            switch role {
                            case .member: "Parent / Member"
                            case .caregiver: "Caregiver"
                            case .owner: "Owner"
                            }
                        }
                    }

                    Text("Single-use code valid for 24 hours. An owner still taps Accept before they see any entries.")
                        .blTextRole(.callout)
                        .foregroundStyle(theme.textSecondary)

                    if let errorMessage, !errorMessage.isEmpty {
                        Text(errorMessage)
                            .blTextRole(.caption)
                            .foregroundStyle(theme.danger.ink)
                    }
                }
            },
            footer: {
                if let created = createdInvite {
                    VStack(spacing: BLSpacing.space2) {
                        BLButton(
                            "Copy code",
                            variant: .primary,
                            size: .lg,
                            isBlock: true
                        ) {
                            onCopyCode(created.code)
                        }

                        BLButton(
                            "Done",
                            variant: .secondary,
                            size: .md,
                            isBlock: true,
                            action: onClose
                        )
                    }
                } else {
                    BLButton(
                        isCreating ? "Creating…" : "Create one-time code",
                        variant: .primary,
                        size: .lg,
                        isBlock: true
                    ) {
                        submit()
                    }
                    .disabled(isCreating)
                }
            }
        )
    }

    @ViewBuilder
    private var labelField: some View {
        let field = BLTextField(
            label: "Who is this for? (optional)",
            placeholder: "e.g. Grandma",
            text: $label
        )
        #if os(iOS)
        field.textInputAutocapitalization(.words)
        #else
        field
        #endif
    }

    private func createdDetail(_ invite: HouseholdInviteDTO) -> String {
        var parts: [String] = []
        if let rawLabel = invite.label?.trimmingCharacters(in: .whitespacesAndNewlines), !rawLabel.isEmpty {
            parts.append(rawLabel)
        }
        parts.append(householdRoleLabel(invite.role))
        parts.append("Valid for 24 hours")
        return parts.joined(separator: " · ")
    }

    private func submit() {
        guard !isCreating else { return }
        errorMessage = nil
        isCreating = true
        let trimmedLabel = label.trimmingCharacters(in: .whitespacesAndNewlines)
        let optionalLabel = trimmedLabel.isEmpty ? nil : trimmedLabel
        let role = selectedRole

        Task { @MainActor in
            defer { isCreating = false }
            do {
                let created = try await onCreate(optionalLabel, role)
                createdInvite = created
            } catch {
                errorMessage = error.localizedDescription
            }
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
        inviteCode
            .filter { !$0.isWhitespace && $0 != "-" }
            .uppercased()
    }

    private var canSubmit: Bool {
        (cleanedInviteCode.count == 8 || cleanedInviteCode.count == 6) && !isSubmitting
    }

    var body: some View {
        BLSheetContainer(
            isPresented: true,
            title: "Join a household",
            showScrim: true,
            onClose: onClose,
            content: {
                Text("Enter the one-time invite code from a household owner. They will tap Accept to let you in.")
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
                    isSubmitting ? "Sending…" : "Request to join",
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
            placeholder: "K7M9-P4X2",
            text: $inviteCode
        )
        .autocorrectionDisabled()

        #if os(iOS)
        field
            .keyboardType(.asciiCapable)
            .textInputAutocapitalization(.characters)
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
    @State private var maxBirthDate: Date
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
        _maxBirthDate = State(initialValue: today)
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
                                in: ...maxBirthDate,
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
