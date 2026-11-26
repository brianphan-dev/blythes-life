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

    @State private var isScheduleSheetOpen = false
    @State private var isMembersSheetOpen = false
    @State private var isImportingCSV = false
    @State private var isExportingFile = false
    @State private var exportDocument: BLExportFileDocument?
    @State private var exportContentType: UTType = .json
    @State private var exportFilename: String = "blythes-life-backup.json"
    @State private var isDeleteAccountAlertOpen = false

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
                    onCopyCode: copyInviteCode,
                    onRotateCode: rotateInviteCode,
                    onClose: { isMembersSheetOpen = false }
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
                store.signOutOnThisDevice()
                store.authEmail = nil
                store.displayName = nil
                store.showInfoToast("Account removed from this device")
            }
        } message: {
            Text("This signs you out and removes your account link from this device. Export a backup first if you want a copy.")
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
                        showDivider: false,
                        onTap: copyInviteCode
                    ) {
                        BLButton("Rotate", variant: .secondary, size: .sm, action: rotateInviteCode)
                    }
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
        settingsGroup(title: "Account") {
            BLCard(isFlush: true) {
                VStack(spacing: 0) {
                    if store.isSignedInWithApple {
                        BLListRow(
                            label: "Signed in with Apple",
                            detail: store.authEmail
                        )
                    } else {
                        #if canImport(AuthenticationServices)
                        VStack(alignment: .leading, spacing: BLSpacing.space2) {
                            Text("Sign in to keep entries updated on every device")
                                .blTextRole(.caption)
                                .foregroundStyle(theme.textSecondary)

                            SignInWithAppleButton(.signIn) { request in
                                request.requestedScopes = [.fullName, .email]
                            } onCompletion: { result in
                                handleAppleSignIn(result)
                            }
                            .signInWithAppleButtonStyle(colorMode == .night ? .white : .black)
                            .frame(height: 48)
                            .clipShape(RoundedRectangle(cornerRadius: BLRadius.md, style: .continuous))
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

                    if store.isSignedInWithApple {
                        BLListRow(
                            label: "Sign out",
                            isDanger: true,
                            onTap: { store.signOutOnThisDevice() }
                        )
                    }

                    BLListRow(
                        label: "Delete account",
                        detail: "Removes your account and entries on every device",
                        isDanger: true,
                        showDivider: false,
                        onTap: { isDeleteAccountAlertOpen = true }
                    )
                }
            }
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
        let newCode = String(format: "%06d", Int.random(in: 100_000 ... 999_999))
        store.household.inviteCode = newCode
        store.showInfoToast("Invite code updated · \(store.formattedInviteCode)")
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
        switch result {
        case .success(let auth):
            if let credential = auth.credential as? ASAuthorizationAppleIDCredential {
                if let email = credential.email, !email.isEmpty {
                    store.authEmail = email
                }
                if let nameComponents = credential.fullName {
                    let formatted = PersonNameComponentsFormatter().string(from: nameComponents)
                        .trimmingCharacters(in: .whitespacesAndNewlines)
                    if !formatted.isEmpty {
                        store.displayName = formatted
                    }
                }
                store.isSignedInWithApple = true
                store.showInfoToast("Signed in with Apple")
            }
        case .failure:
            store.showInfoToast("Sign in with Apple was cancelled")
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
                            BLButton("Rotate", variant: .secondary, size: .md, action: onRotateCode)
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
