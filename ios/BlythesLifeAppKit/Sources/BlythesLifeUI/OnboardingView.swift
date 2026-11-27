import BlythesLifeCore
import BlythesLifeDesignSystem
import BlythesLifeShared
import SwiftUI
#if canImport(AuthenticationServices)
import AuthenticationServices
#endif

/// Calm welcome and household setup flow shown when the user is signed out or has not yet created/joined a household.
/// Adapts cleanly across iPhone, iPad, and iPhone Duo (Folded, Unfolded, and Tabletop).
@MainActor
public struct OnboardingView: View {
    private enum HouseholdSetupMode: Hashable {
        case create
        case join
    }

    @Environment(\.blTheme) private var theme
    @Environment(\.blColorMode) private var colorMode
    @Environment(\.duoLayout) private var duoLayout

    private let store: BlythesLifeStore

    @State private var pendingRawNonce: String?
    @State private var signInError: String?

    @State private var setupMode: HouseholdSetupMode = .create
    @State private var babyName: String = ""
    @State private var includeBirthDate: Bool = true
    @State private var birthDate: Date = Date()
    @State private var maxBirthDate: Date = Date()
    @State private var householdName: String = ""
    @State private var inviteCode: String = ""
    @State private var memberDisplayName: String = ""
    @State private var setupError: String?
    @State private var isSubmitting = false
    @State private var isSigningOut = false
    @State private var isCheckingApproval = false

    public init(store: BlythesLifeStore) {
        self.store = store
        _memberDisplayName = State(initialValue: store.displayName ?? "")
    }

    public var body: some View {
        ZStack {
            theme.bgApp.ignoresSafeArea()

            VStack(spacing: 0) {
                topBar

                ScrollView {
                    VStack(alignment: .leading, spacing: 0) {
                        switch store.sessionStage {
                        case .signedOut, .ready:
                            welcomeContent
                        case .needsHouseholdSetup:
                            householdSetupContent
                        case .awaitingApproval:
                            awaitingApprovalView
                        }
                    }
                    .frame(maxWidth: 460, alignment: .leading)
                    .frame(maxWidth: .infinity)
                    .padding(.horizontal, BLSpacing.screenGutter)
                    .padding(.top, contentTopPadding)
                    .padding(.bottom, BLSpacing.space10)
                }
                .scrollIndicators(.hidden)
            }
        }
        .onAppear {
            prefillMemberDisplayNameIfNeeded()
        }
        .onChange(of: store.displayName) { _, _ in
            prefillMemberDisplayNameIfNeeded()
        }
        .onChange(of: store.sessionStage) { _, newStage in
            signInError = nil
            setupError = nil
            switch newStage {
            case .needsHouseholdSetup:
                prefillMemberDisplayNameIfNeeded()
            case .awaitingApproval:
                break
            case .signedOut:
                let today = Date()
                setupMode = .create
                babyName = ""
                includeBirthDate = true
                maxBirthDate = today
                birthDate = today
                householdName = ""
                inviteCode = ""
                memberDisplayName = ""
            case .ready:
                break
            }
        }
        .onChange(of: setupMode) { _, _ in
            setupError = nil
        }
        .task(id: store.sessionStage) {
            guard store.sessionStage == .awaitingApproval else { return }
            while !Task.isCancelled && store.sessionStage == .awaitingApproval {
                try? await Task.sleep(nanoseconds: 4_000_000_000)
                guard !Task.isCancelled && store.sessionStage == .awaitingApproval else { break }
                await store.checkJoinApprovalStatusAsync()
            }
        }
    }

    // MARK: - Top Bar & Layout Metrics

    private var topBar: some View {
        HStack {
            Spacer()
            BLIconButton(
                icon: colorMode == .night ? BLSymbol.sun : BLSymbol.moon,
                label: "Toggle night mode",
                variant: .outline
            ) {
                store.toggleTheme()
            }
        }
        .padding(.top, BLSpacing.space2)
        .padding(.horizontal, BLSpacing.screenGutter)
        .padding(.bottom, BLSpacing.space2)
    }

    private var contentTopPadding: CGFloat {
        if duoLayout.isTabletop {
            return BLSpacing.space2
        }
        if duoLayout.usesSplitLayout {
            return BLSpacing.space8
        }
        return BLSpacing.space4
    }

    // MARK: - Stage 1: Welcome (Signed Out)

    private var welcomeContent: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Blythe's Life")
                .font(BLFont.display(size: 38, weight: .medium, tabularNumerals: false))
                .tracking(BLFont.displayTrackingRatio * 38)
                .foregroundStyle(theme.textPrimary)
                .padding(.bottom, BLSpacing.space4)

            Rectangle()
                .fill(theme.borderHairline)
                .frame(height: BLSpacing.borderWidth)
                .padding(.bottom, BLSpacing.space4)

            Text("Daily care in one tap, plus paper logs updated on every device.")
                .blTextRole(.body)
                .foregroundStyle(theme.textSecondary)
                .padding(.bottom, BLSpacing.space6)

            BLCard {
                VStack(alignment: .leading, spacing: BLSpacing.space4) {
                    VStack(alignment: .leading, spacing: BLSpacing.space2) {
                        Text("Get started")
                            .blMicroLabel()

                        Text("Sign in with Apple to create a family household or join with an invite code.")
                            .blTextRole(.callout)
                            .foregroundStyle(theme.textSecondary)
                    }

                    appleSignInControl

                    if store.isAuthenticating {
                        HStack(spacing: BLSpacing.space2) {
                            ProgressView()
                                .controlSize(.small)
                                .tint(theme.accentText)
                            Text("Signing in with Apple…")
                                .blTextRole(.caption)
                                .foregroundStyle(theme.textSecondary)
                        }
                    }

                    if let signInError, !signInError.isEmpty {
                        Text(signInError)
                            .blTextRole(.caption)
                            .foregroundStyle(theme.danger.ink)
                    }
                }
            }

            VStack(spacing: BLSpacing.space1) {
                BLButton("Explore with sample data", variant: .ghost, size: .md) {
                    signInError = nil
                    store.enterDemoPreview()
                }
                .disabled(store.isAuthenticating)

                Text("Try the app locally with example entries. Nothing is uploaded.")
                    .blTextRole(.caption)
                    .foregroundStyle(theme.textTertiary)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
            .padding(.top, BLSpacing.space6)
        }
    }

    @ViewBuilder
    private var appleSignInControl: some View {
        #if canImport(AuthenticationServices)
        SignInWithAppleButton(.signIn) { request in
            signInError = nil
            let raw = AppleNonceGenerator.randomNonceString()
            pendingRawNonce = raw
            request.nonce = AppleNonceGenerator.sha256Hex(raw)
            request.requestedScopes = [.fullName, .email]
        } onCompletion: { result in
            handleAppleSignIn(result)
        }
        .id(colorMode)
        .signInWithAppleButtonStyle(colorMode == .night ? .white : .black)
        .frame(height: 50)
        .clipShape(RoundedRectangle(cornerRadius: BLRadius.md, style: .continuous))
        .disabled(store.isAuthenticating)
        .opacity(store.isAuthenticating ? 0.5 : 1.0)
        #else
        Text("Sign in with Apple is available on iPhone and iPad.")
            .blTextRole(.caption)
            .foregroundStyle(theme.textSecondary)
        #endif
    }

    // MARK: - Stage 2: Household Setup

    private var householdSetupContent: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(signedInMicroLabel)
                .blMicroLabel()
                .padding(.bottom, BLSpacing.space1)

            Text("Set up your household")
                .blTextRole(.display)
                .foregroundStyle(theme.textPrimary)
                .padding(.bottom, BLSpacing.space2)

            Text("Start a new log for your baby, or join a household that already exists.")
                .blTextRole(.body)
                .foregroundStyle(theme.textSecondary)
                .padding(.bottom, BLSpacing.space5)

            BLSegmentedControl(
                options: [HouseholdSetupMode.create, .join],
                selection: $setupMode,
                size: .md,
                isBlock: true
            ) { mode in
                switch mode {
                case .create: "Start new"
                case .join: "Join with code"
                }
            }
            .padding(.bottom, BLSpacing.space4)

            switch setupMode {
            case .create:
                createHouseholdCard
            case .join:
                joinHouseholdCard
            }

            HStack {
                Spacer()
                BLButton(
                    isSigningOut ? "Signing out…" : "Sign out",
                    variant: .ghost,
                    size: .sm
                ) {
                    submitSignOut()
                }
                .disabled(isSubmitting || isSigningOut)
                Spacer()
            }
            .padding(.top, BLSpacing.space5)
        }
    }

    private var createHouseholdCard: some View {
        BLCard {
            VStack(alignment: .leading, spacing: BLSpacing.space5) {
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

                        BLSwitch(isOn: $includeBirthDate, label: "Include birth date")
                    }

                    if includeBirthDate {
                        HStack(spacing: BLSpacing.space3) {
                            Text("Birth date")
                                .blMicroLabel()
                            Spacer()
                            DatePicker(
                                "Birth date",
                                selection: $birthDate,
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

                householdNameField

                if let setupError, !setupError.isEmpty {
                    Text(setupError)
                        .blTextRole(.caption)
                        .foregroundStyle(theme.danger.ink)
                }

                BLButton(
                    isSubmitting ? "Creating…" : "Create household",
                    variant: .primary,
                    size: .lg,
                    isBlock: true
                ) {
                    submitCreateHousehold()
                }
                .disabled(!canCreateHousehold)
            }
        }
    }

    private var joinHouseholdCard: some View {
        BLCard {
            VStack(alignment: .leading, spacing: BLSpacing.space5) {
                Text("Enter the one-time invite code from a household owner. They will tap Accept to let you in.")
                    .blTextRole(.callout)
                    .foregroundStyle(theme.textSecondary)

                inviteCodeField

                memberDisplayNameField

                if let setupError, !setupError.isEmpty {
                    Text(setupError)
                        .blTextRole(.caption)
                        .foregroundStyle(theme.danger.ink)
                }

                BLButton(
                    isSubmitting ? "Sending…" : "Request to join",
                    variant: .primary,
                    size: .lg,
                    isBlock: true
                ) {
                    submitJoinHousehold()
                }
                .disabled(!canJoinHousehold)
            }
        }
    }

    // MARK: - Stage 3: Awaiting Owner Approval

    private var awaitingApprovalView: some View {
        let rawName = store.pendingJoinRequest?.householdName.trimmingCharacters(in: .whitespacesAndNewlines)
        let householdDisplay = (rawName?.isEmpty == false) ? rawName! : "the household"
        let requestedRole = store.pendingJoinRequest?.requestedRole ?? .member

        return VStack(alignment: .leading, spacing: 0) {
            Text("Waiting for approval")
                .blMicroLabel()
                .padding(.bottom, BLSpacing.space1)

            Text("Request sent")
                .blTextRole(.display)
                .foregroundStyle(theme.textPrimary)
                .padding(.bottom, BLSpacing.space2)

            Text("Waiting for an owner of \(householdDisplay) to accept your request. This updates automatically.")
                .blTextRole(.body)
                .foregroundStyle(theme.textSecondary)
                .padding(.bottom, BLSpacing.space5)

            BLCard {
                VStack(alignment: .leading, spacing: BLSpacing.space4) {
                    HStack(alignment: .center, spacing: BLSpacing.space3) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Household")
                                .blMicroLabel()
                            Text(householdDisplay)
                                .blTextRole(.headline)
                                .foregroundStyle(theme.textPrimary)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)

                        BLBadge(roleLabel(requestedRole), tone: .neutral)
                    }

                    Rectangle()
                        .fill(theme.borderHairline)
                        .frame(height: BLSpacing.borderWidth)

                    HStack(spacing: BLSpacing.space2) {
                        ProgressView()
                            .controlSize(.small)
                            .tint(theme.accentText)
                        Text("Checking for approval…")
                            .blTextRole(.caption)
                            .foregroundStyle(theme.textSecondary)
                    }

                    VStack(spacing: BLSpacing.space2) {
                        BLButton(
                            isCheckingApproval ? "Checking…" : "Check status",
                            variant: .primary,
                            size: .lg,
                            isBlock: true
                        ) {
                            checkApprovalStatus()
                        }
                        .disabled(isCheckingApproval || isSigningOut)

                        BLButton(
                            "Use a different code",
                            variant: .secondary,
                            size: .md,
                            isBlock: true
                        ) {
                            store.cancelPendingJoinRequestLocally()
                        }
                        .disabled(isCheckingApproval || isSigningOut)
                    }
                }
            }

            HStack {
                Spacer()
                BLButton(
                    isSigningOut ? "Signing out…" : "Sign out",
                    variant: .ghost,
                    size: .sm
                ) {
                    submitSignOut()
                }
                .disabled(isCheckingApproval || isSigningOut)
                Spacer()
            }
            .padding(.top, BLSpacing.space5)
        }
    }

    // MARK: - Form Fields

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

    @ViewBuilder
    private var householdNameField: some View {
        let field = BLTextField(
            label: "Household name (optional)",
            placeholder: householdNamePlaceholder,
            text: $householdName
        )
        #if os(iOS)
        field.textInputAutocapitalization(.words)
        #else
        field
        #endif
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

    @ViewBuilder
    private var memberDisplayNameField: some View {
        let field = BLTextField(
            label: "Your name (optional)",
            placeholder: "e.g. Brian",
            text: $memberDisplayName
        )
        #if os(iOS)
        field.textInputAutocapitalization(.words)
        #else
        field
        #endif
    }

    // MARK: - Validation & Derived Labels

    private var signedInMicroLabel: String {
        if let name = store.displayName?.trimmingCharacters(in: .whitespacesAndNewlines), !name.isEmpty {
            return "Signed in as \(name)"
        }
        return "Signed in"
    }

    private var trimmedBabyName: String {
        babyName.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var householdNamePlaceholder: String {
        trimmedBabyName.isEmpty ? "e.g. Blythe's household" : "e.g. \(trimmedBabyName)'s household"
    }

    private var cleanedInviteCode: String {
        inviteCode
            .filter { !$0.isWhitespace && $0 != "-" }
            .uppercased()
    }

    private var canCreateHousehold: Bool {
        !trimmedBabyName.isEmpty && !isSubmitting && !isSigningOut
    }

    private var canJoinHousehold: Bool {
        (cleanedInviteCode.count == 8 || cleanedInviteCode.count == 6) && !isSubmitting && !isSigningOut
    }

    private func roleLabel(_ role: HouseholdRole) -> String {
        switch role {
        case .owner: "Owner"
        case .member: "Member"
        case .caregiver: "Caregiver"
        }
    }

    // MARK: - Actions

    private func prefillMemberDisplayNameIfNeeded() {
        guard memberDisplayName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              let name = store.displayName?.trimmingCharacters(in: .whitespacesAndNewlines),
              !name.isEmpty
        else {
            return
        }
        memberDisplayName = name
    }

    private func submitCreateHousehold() {
        guard canCreateHousehold else { return }
        setupError = nil
        isSubmitting = true
        let name = trimmedBabyName
        let hName = householdName.trimmingCharacters(in: .whitespacesAndNewlines)
        let selectedDate = includeBirthDate ? birthDate : nil

        Task { @MainActor in
            defer { isSubmitting = false }
            do {
                try await store.createHouseholdAndProfileAsync(
                    householdName: hName,
                    babyName: name,
                    birthDate: selectedDate
                )
            } catch {
                setupError = error.localizedDescription
            }
        }
    }

    private func submitJoinHousehold() {
        guard canJoinHousehold else { return }
        setupError = nil
        isSubmitting = true
        let code = cleanedInviteCode
        let trimmedName = memberDisplayName.trimmingCharacters(in: .whitespacesAndNewlines)
        let optionalName = trimmedName.isEmpty ? nil : trimmedName

        Task { @MainActor in
            defer { isSubmitting = false }
            do {
                try await store.joinHouseholdAsync(inviteCode: code, displayName: optionalName)
            } catch {
                setupError = error.localizedDescription
            }
        }
    }

    private func checkApprovalStatus() {
        guard !isCheckingApproval, !isSigningOut else { return }
        isCheckingApproval = true
        Task { @MainActor in
            defer { isCheckingApproval = false }
            await store.checkJoinApprovalStatusAsync()
        }
    }

    private func submitSignOut() {
        guard !isSigningOut, !isSubmitting, !isCheckingApproval else { return }
        setupError = nil
        isSigningOut = true
        Task { @MainActor in
            defer { isSigningOut = false }
            await store.signOutOnThisDeviceAsync()
        }
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
                signInError = "Could not complete Sign in with Apple."
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

            signInError = nil
            Task { @MainActor in
                do {
                    try await store.completeAppleSignIn(
                        identityToken: identityToken,
                        rawNonce: rawNonce,
                        authorizationCode: authorizationCode,
                        displayName: formattedName,
                        email: email
                    )
                } catch {
                    signInError = error.localizedDescription
                }
            }

        case .failure(let error):
            if let authError = error as? ASAuthorizationError, authError.code == .canceled {
                signInError = nil
                store.showInfoToast("Sign in with Apple was cancelled")
            } else {
                signInError = "Sign in with Apple could not be completed."
            }
        }
    }
    #endif
}
