import BlythesLifeCore
import BlythesLifeDesignSystem
import BlythesLifeShared
import SwiftUI
import UniformTypeIdentifiers
#if os(iOS) && canImport(PhotosUI)
import PhotosUI
#endif
#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

// MARK: - SheetsView

/// Grandma's paper log scanning hub listing scan/import triggers and recent scanned sheets.
@MainActor
public struct SheetsView: View {
    @Environment(\.blTheme) private var theme

    private let store: BlythesLifeStore
    private let onOpenReview: (ScannedSheetRecord) -> Void

    #if os(iOS) && canImport(UIKit)
    @State private var isCameraPresented = false
    #endif
    #if os(iOS) && canImport(PhotosUI)
    @State private var isPhotoPickerPresented = false
    @State private var selectedPhotoItem: PhotosPickerItem?
    #endif
    #if !os(iOS)
    @State private var isImageFileImporterPresented = false
    #endif

    public init(
        store: BlythesLifeStore,
        onOpenReview: @escaping (ScannedSheetRecord) -> Void
    ) {
        self.store = store
        self.onOpenReview = onOpenReview
    }

    public var body: some View {
        HingeSplitContainer(
            padLeadingRatio: 0.46,
            leading: {
                ScrollView {
                    VStack(alignment: .leading, spacing: 0) {
                        headerView
                            .padding(.horizontal, -BLSpacing.screenGutter)
                        scanHeroCard
                        if store.isProcessingScan {
                            scanProcessingCard
                                .padding(.top, BLSpacing.space3)
                        }
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
                        recentHeader
                            .padding(.top, BLSpacing.space4)
                        recentSheetsCard
                    }
                    .padding(.horizontal, BLSpacing.screenGutter)
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
                            scanHeroCard
                            if store.isProcessingScan {
                                scanProcessingCard
                                    .padding(.top, BLSpacing.space3)
                            }
                            recentHeader
                                .padding(.top, BLSpacing.space5)
                            recentSheetsCard
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
        #if os(iOS) && canImport(UIKit)
        .fullScreenCover(isPresented: $isCameraPresented) {
            CameraCaptureSheet(
                onCapture: { imageData in
                    isCameraPresented = false
                    handlePickedImageData(imageData)
                },
                onCancel: {
                    isCameraPresented = false
                }
            )
            .ignoresSafeArea()
        }
        #endif
        #if os(iOS) && canImport(PhotosUI)
        .photosPicker(
            isPresented: $isPhotoPickerPresented,
            selection: $selectedPhotoItem,
            matching: .images
        )
        .onChange(of: selectedPhotoItem) { _, newItem in
            guard let newItem else { return }
            Task { @MainActor in
                defer { selectedPhotoItem = nil }
                do {
                    if let imageData = try await newItem.loadTransferable(type: Data.self),
                       !imageData.isEmpty
                    {
                        handlePickedImageData(imageData)
                    } else {
                        store.showInfoToast("Could not read selected photo")
                    }
                } catch {
                    store.showInfoToast("Could not read selected photo")
                }
            }
        }
        #endif
        #if !os(iOS)
        .fileImporter(
            isPresented: $isImageFileImporterPresented,
            allowedContentTypes: [.image],
            allowsMultipleSelection: false
        ) { result in
            handleImportedImageFile(result)
        }
        #endif
    }

    private var headerView: some View {
        HStack(alignment: .bottom) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Grandma's paper logs")
                    .blMicroLabel()
                Text("Sheets")
                    .blTextRole(.display)
                    .foregroundStyle(theme.textPrimary)
            }
            Spacer()
        }
        .padding(.top, 6)
        .padding(.horizontal, BLSpacing.screenGutter)
        .padding(.bottom, BLSpacing.space3)
    }

    private var scanHeroCard: some View {
        BLCard {
            VStack(alignment: .leading, spacing: 14) {
                Text("Photograph today's sheet. Nothing is saved until you confirm each entry.")
                    .blTextRole(.callout)
                    .foregroundStyle(theme.textSecondary)

                VStack(spacing: BLSpacing.space2) {
                    BLButton(
                        "Scan today's sheet",
                        variant: .primary,
                        size: .lg,
                        isBlock: true,
                        icon: BLSymbol.scan,
                        action: startPrimaryScan
                    )
                    .disabled(store.isProcessingScan)

                    importPhotoControl

                    if !store.hasLiveSession {
                        BLButton(
                            "Open sample sheet",
                            variant: .ghost,
                            size: .sm,
                            isBlock: true,
                            action: openSampleSheet
                        )
                        .disabled(store.isProcessingScan)
                    }
                }
            }
        }
    }

    private var scanProcessingCard: some View {
        BLCard(tone: .surface) {
            HStack(alignment: .center, spacing: BLSpacing.space3) {
                ProgressView()
                    .tint(theme.accentText)

                VStack(alignment: .leading, spacing: 2) {
                    Text("Reading Grandma's sheet…")
                        .font(BLFont.ui(size: 16, weight: .semibold))
                        .foregroundStyle(theme.textPrimary)

                    Text("Nothing is saved until you confirm each entry.")
                        .blTextRole(.caption)
                        .foregroundStyle(theme.textSecondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    @ViewBuilder
    private var importPhotoControl: some View {
        #if os(iOS) && canImport(PhotosUI)
        BLButton(
            "Import a photo",
            variant: .secondary,
            size: .md,
            isBlock: true,
            icon: BLSymbol.photo
        ) {
            isPhotoPickerPresented = true
        }
        .disabled(store.isProcessingScan)
        #else
        BLButton(
            "Import a photo",
            variant: .secondary,
            size: .md,
            isBlock: true,
            icon: BLSymbol.photo
        ) {
            isImageFileImporterPresented = true
        }
        .disabled(store.isProcessingScan)
        #endif
    }

    private var recentHeader: some View {
        HStack {
            Text("Recent")
                .blMicroLabel()
            Spacer()
        }
        .padding(.bottom, BLSpacing.space2)
    }

    @ViewBuilder
    private var recentSheetsCard: some View {
        if store.scannedSheets.isEmpty {
            BLCard {
                Text("No sheets scanned yet. Photograph Grandma's paper log above to start.")
                    .blTextRole(.callout)
                    .foregroundStyle(theme.textSecondary)
            }
        } else {
            BLCard(isFlush: true) {
                VStack(spacing: 0) {
                    ForEach(Array(store.scannedSheets.enumerated()), id: \.element.id) { index, sheet in
                        let isLast = index == store.scannedSheets.count - 1
                        BLListRow(
                            label: sheet.listLabel,
                            detail: sheet.subtitle,
                            showsChevron: true,
                            showDivider: !isLast,
                            onTap: {
                                if sheet.status == .pendingReview {
                                    onOpenReview(sheet)
                                } else {
                                    let count = sheet.confirmedEntryCount
                                    let noun = count == 1 ? "entry" : "entries"
                                    store.showInfoToast("\(count) \(noun) already saved from \(sheet.listLabel)")
                                }
                            }
                        ) {
                            statusBadge(for: sheet.status)
                        }
                    }
                }
            }
        }
    }

    private func statusBadge(for status: PaperScanStatus) -> some View {
        switch status {
        case .pendingReview:
            BLBadge("Needs review", tone: .warn)
        case .confirmed:
            BLBadge("Confirmed", tone: .ok)
        case .discarded:
            BLBadge("Discarded", tone: .neutral)
        }
    }

    private func startPrimaryScan() {
        guard !store.isProcessingScan else { return }
        #if os(iOS) && canImport(UIKit)
        if UIImagePickerController.isSourceTypeAvailable(.camera) {
            isCameraPresented = true
            return
        }
        #if canImport(PhotosUI)
        isPhotoPickerPresented = true
        #else
        openSampleSheet()
        #endif
        #else
        isImageFileImporterPresented = true
        #endif
    }

    private func openSampleSheet() {
        guard !store.isProcessingScan else { return }
        if let pending = store.pendingReviewSheet {
            onOpenReview(pending)
        } else {
            let freshSheet = makeImportedSheet(imageData: nil)
            store.addScannedSheet(freshSheet)
            onOpenReview(freshSheet)
        }
    }

    private func handlePickedImageData(_ data: Data) {
        guard !store.isProcessingScan else { return }
        let fallbackDrafts = store.hasLiveSession ? [] : makeImportedSheet(imageData: nil).drafts
        Task { @MainActor in
            do {
                let sheet = try await store.processScannedPhotoAsync(
                    data,
                    fallbackDrafts: fallbackDrafts
                )
                onOpenReview(sheet)
            } catch {
                store.showInfoToast(error.localizedDescription)
            }
        }
    }

    #if !os(iOS)
    private func handleImportedImageFile(_ result: Result<[URL], any Error>) {
        switch result {
        case .success(let urls):
            guard let url = urls.first else { return }
            let accessed = url.startAccessingSecurityScopedResource()
            defer {
                if accessed { url.stopAccessingSecurityScopedResource() }
            }
            if let data = try? Data(contentsOf: url), !data.isEmpty {
                handlePickedImageData(data)
            } else {
                store.showInfoToast("Could not read selected photo")
            }
        case .failure:
            store.showInfoToast("Photo selection cancelled")
        }
    }
    #endif

    /// Creates a structured paper-sheet review record (from a picked photo or demo sheet) so every scan is reviewable offline.
    private func makeImportedSheet(imageData: Data?) -> ScannedSheetRecord {
        let clock = FormattingHelpers.formatClock(store.now, timeZone: store.profileTimeZone)
        let now = store.now
        let tBottle = now.addingTimeInterval(-35 * 60)
        let tDiaper = now.addingTimeInterval(-20 * 60)
        let tDiaperAlt = now.addingTimeInterval(-10 * 60)
        let clockA = FormattingHelpers.formatClock(tDiaper, timeZone: store.profileTimeZone)
        let clockB = FormattingHelpers.formatClock(tDiaperAlt, timeZone: store.profileTimeZone)
        let clockBottle = FormattingHelpers.formatClock(tBottle, timeZone: store.profileTimeZone)

        let drafts: [ScanReviewDraftItem] = [
            ScanReviewDraftItem(
                id: "imp-diaper-\(UUID().uuidString.prefix(4))",
                rowKey: "d-imp",
                eventType: .diaper,
                startedAt: tDiaper,
                title: "Diaper",
                detail: "Pee L",
                metadata: .diaper(DiaperMetadata(peeSize: .large, poopSize: nil, rash: false)),
                matchAction: .create,
                isSuggestion: false,
                ambiguityQuestion: "The time was written over. Which is it?",
                ambiguityOptions: [clockA, clockB],
                ambiguityOptionDates: [clockA: tDiaper, clockB: tDiaperAlt],
                resolvedOption: nil,
                isIncluded: true,
                boundingBox: NormalizedBoundingBox(x: 0.08, y: 0.42, width: 0.84, height: 0.14)
            ),
            ScanReviewDraftItem(
                id: "imp-bottle-\(UUID().uuidString.prefix(4))",
                rowKey: "b-imp",
                eventType: .feeding,
                startedAt: tBottle,
                title: "Bottle",
                detail: "3.5 oz formula",
                metadata: .feeding(FeedingMetadata(method: .bottle, substance: .formula, amountOz: 3.5)),
                matchAction: .create,
                isSuggestion: false,
                isIncluded: true,
                boundingBox: NormalizedBoundingBox(x: 0.08, y: 0.24, width: 0.84, height: 0.14)
            ),
            ScanReviewDraftItem(
                id: "imp-vitd-\(UUID().uuidString.prefix(4))",
                rowKey: "b-imp",
                eventType: .medicine,
                startedAt: tBottle,
                title: "Vitamin D",
                detail: "The row is labelled + VIT D",
                savedDetail: "1 drop · supplement",
                metadata: .medicine(MedicineMetadata(name: "Vitamin D", category: .supplement, dose: 1, unit: .drops)),
                matchAction: .create,
                isSuggestion: true,
                isIncluded: false,
                boundingBox: NormalizedBoundingBox(x: 0.08, y: 0.24, width: 0.84, height: 0.14)
            )
        ]

        let lines: [ScannedSheetLinePreview] = [
            ScannedSheetLinePreview(
                id: "b-imp",
                label: "BOTTLE",
                pills: ["FORMULA", "+ VIT D"],
                targetText: "3–4 oz",
                handwrittenText: "3½ oz  \(clockBottle)"
            ),
            ScannedSheetLinePreview(
                id: "d-imp",
                label: "DIAPER",
                handwrittenText: "\(clockA)  pee L",
                overwrittenDigits: "2/3"
            )
        ]

        return ScannedSheetRecord(
            title: "Grandma's sheet, \(clock)",
            subtitle: "2 new · 1 suggested",
            listLabel: "Today, \(clock)",
            scannedAt: now,
            status: .pendingReview,
            drafts: drafts,
            previewLines: lines,
            imageData: imageData,
            confirmedEntryCount: 0
        )
    }
}

// MARK: - CameraCaptureSheet

#if os(iOS) && canImport(UIKit)
private struct CameraCaptureSheet: UIViewControllerRepresentable {
    let onCapture: (Data) -> Void
    let onCancel: () -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(onCapture: onCapture, onCancel: onCancel)
    }

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = .camera
        picker.allowsEditing = false
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    @MainActor
    final class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        private let onCapture: (Data) -> Void
        private let onCancel: () -> Void

        init(onCapture: @escaping (Data) -> Void, onCancel: @escaping () -> Void) {
            self.onCapture = onCapture
            self.onCancel = onCancel
        }

        func imagePickerController(
            _ picker: UIImagePickerController,
            didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]
        ) {
            if let image = info[.originalImage] as? UIImage,
               let data = image.jpegData(compressionQuality: 0.9)
            {
                onCapture(data)
            } else {
                onCancel()
            }
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            onCancel()
        }
    }
}
#endif

// MARK: - ScanReviewView

/// Full-screen paper scan Review & Confirm view.
/// Shows top photo / bottom draft list on iPhone & Duo Folded, and pinned left photo / right draft list across the hinge on Duo Unfolded & iPad.
@MainActor
public struct ScanReviewView: View {
    @Environment(\.blTheme) private var theme

    private let sheet: ScannedSheetRecord
    private let store: BlythesLifeStore
    private let onCancel: () -> Void
    private let onComplete: () -> Void

    @State private var drafts: [ScanReviewDraftItem]
    @State private var selectedDraftId: String?
    @State private var isConfirming = false

    public init(
        sheet: ScannedSheetRecord,
        store: BlythesLifeStore,
        onCancel: @escaping () -> Void,
        onComplete: @escaping () -> Void
    ) {
        self.sheet = sheet
        self.store = store
        self.onCancel = onCancel
        self.onComplete = onComplete

        let initialDrafts = sheet.drafts
        let initialSelected = initialDrafts.first(where: { Self.draftNeedsResolution($0) })?.id
            ?? initialDrafts.first(where: { $0.isIncluded })?.id
            ?? initialDrafts.first?.id

        _drafts = State(initialValue: initialDrafts)
        _selectedDraftId = State(initialValue: initialSelected)
    }

    private var orderedDrafts: [ScanReviewDraftItem] {
        drafts.sorted { lhs, rhs in
            let lhsRank = Self.sortRank(for: lhs)
            let rhsRank = Self.sortRank(for: rhs)
            if lhsRank != rhsRank {
                return lhsRank < rhsRank
            }
            return lhs.startedAt < rhs.startedAt
        }
    }

    private var selectedDraft: ScanReviewDraftItem? {
        drafts.first(where: { $0.id == selectedDraftId })
    }

    private var includedCount: Int {
        drafts.filter(\.isIncluded).count
    }

    private var unresolvedCount: Int {
        drafts.filter { Self.draftNeedsResolution($0) }.count
    }

    private var canSave: Bool {
        includedCount > 0 && unresolvedCount == 0 && !isConfirming
    }

    private var saveButtonLabel: String {
        if isConfirming {
            return "Saving…"
        }
        if unresolvedCount > 0 {
            let verb = unresolvedCount == 1 ? "entry needs" : "entries need"
            return "\(unresolvedCount) \(verb) a look"
        }
        let noun = includedCount == 1 ? "entry" : "entries"
        return "Save \(includedCount) \(noun)"
    }

    public var body: some View {
        HingeSplitContainer(
            padLeadingRatio: 0.46,
            leading: {
                paperPreviewPane(isSplit: true)
            },
            trailing: {
                draftsAndFooterPane
            },
            compact: {
                GeometryReader { proxy in
                    let photoHeight = max(220, min(330, proxy.size.height * 0.38))
                    VStack(spacing: 0) {
                        paperPreviewPane(isSplit: false)
                            .frame(height: photoHeight)

                        draftsAndFooterPane
                    }
                }
            }
        )
        .background(theme.bgApp.ignoresSafeArea())
    }

    // MARK: - Paper Preview Pane

    private func paperPreviewPane(isSplit: Bool) -> some View {
        ZStack {
            BLColorPrimitives.paper800

            if let data = sheet.imageData, let decodedImage = decodePlatformImage(data) {
                pickedPhotoPreview(image: decodedImage, activeBox: selectedDraft?.boundingBox)
                    .padding(.top, 56)
                    .padding(.horizontal, BLSpacing.space4)
                    .padding(.bottom, BLSpacing.space4)
            } else {
                simulatedPaperSheet(isSplit: isSplit)
                    .padding(.top, isSplit ? 64 : 52)
                    .padding(.horizontal, BLSpacing.space4)
                    .padding(.bottom, BLSpacing.space4)
            }
        }
        .overlay(alignment: .top) {
            HStack {
                BLIconButton(
                    icon: BLSymbol.close,
                    label: "Cancel review",
                    variant: .outline,
                    action: onCancel
                )
                .disabled(isConfirming)
                Spacer()
                BLBadge(sheet.listLabel, tone: .neutral)
            }
            .padding(.top, 10)
            .padding(.horizontal, BLSpacing.space3)
        }
        .clipped()
    }

    private func pickedPhotoPreview(image: Image, activeBox: NormalizedBoundingBox?) -> some View {
        GeometryReader { geo in
            ZStack {
                image
                    .resizable()
                    .scaledToFit()
                    .clipShape(RoundedRectangle(cornerRadius: BLRadius.sm, style: .continuous))
                    .overlay {
                        if let box = activeBox {
                            GeometryReader { imgGeo in
                                RoundedRectangle(cornerRadius: BLRadius.xs, style: .continuous)
                                    .fill(BLColorPrimitives.honey400.opacity(0.22))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: BLRadius.xs, style: .continuous)
                                            .strokeBorder(BLColorPrimitives.honey500, lineWidth: 2)
                                    )
                                    .frame(
                                        width: max(12, imgGeo.size.width * box.width),
                                        height: max(12, imgGeo.size.height * box.height)
                                    )
                                    .position(
                                        x: imgGeo.size.width * (box.x + box.width / 2),
                                        y: imgGeo.size.height * (box.y + box.height / 2)
                                    )
                            }
                        }
                    }
            }
            .frame(width: geo.size.width, height: geo.size.height)
        }
    }

    private func simulatedPaperSheet(isSplit: Bool) -> some View {
        let activeRowKey = selectedDraft?.rowKey
        let lines = sheet.previewLines

        return VStack(spacing: 0) {
            HStack {
                Text("Blythe's Daily Log")
                    .font(BLFont.ui(size: isSplit ? 13 : 12, weight: .semibold))
                    .foregroundStyle(BLColorPrimitives.paper900)
                Spacer()
                Text(sheetDateStamp)
                    .font(BLFont.ui(size: isSplit ? 12 : 11, weight: .medium))
                    .foregroundStyle(BLColorPrimitives.paper700)
            }
            .padding(.bottom, 7)
            .overlay(alignment: .bottom) {
                Rectangle()
                    .fill(BLColorPrimitives.paper900)
                    .frame(height: 1.5)
            }

            ForEach(Array(lines.enumerated()), id: \.element.id) { index, line in
                let isHot = line.id == activeRowKey
                let isLast = index == lines.count - 1
                Button {
                    selectDraft(forRowKey: line.id)
                } label: {
                    HStack(alignment: .center, spacing: 6) {
                        HStack(spacing: 3) {
                            Text(line.label)
                                .font(BLFont.ui(size: 9, weight: .bold))
                                .tracking(0.5)
                                .foregroundStyle(BLColorPrimitives.paper900)

                            ForEach(line.pills, id: \.self) { pill in
                                Text(pill)
                                    .font(BLFont.ui(size: 7, weight: .semibold))
                                    .foregroundStyle(BLColorPrimitives.paper900)
                                    .padding(.horizontal, 3)
                                    .padding(.vertical, 1)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 3, style: .continuous)
                                            .strokeBorder(BLColorPrimitives.paper900, lineWidth: 0.8)
                                    )
                            }
                        }
                        .frame(width: isSplit ? 116 : 102, alignment: .leading)

                        Text(line.targetText ?? "")
                            .font(BLFont.ui(size: 9, weight: .medium, tabularNumerals: true))
                            .foregroundStyle(BLColorPrimitives.paper500)
                            .frame(width: 52, alignment: .leading)
                            .lineLimit(1)

                        handwrittenLineText(line)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                    }
                    .frame(height: isSplit ? 36 : 31)
                    .overlay(alignment: .bottom) {
                        if !isLast {
                            Rectangle()
                                .fill(BLColorPrimitives.paper300)
                                .frame(height: 1)
                        }
                    }
                    .overlay {
                        if isHot {
                            RoundedRectangle(cornerRadius: BLRadius.xs, style: .continuous)
                                .fill(BLColorPrimitives.honey400.opacity(0.20))
                                .overlay(
                                    RoundedRectangle(cornerRadius: BLRadius.xs, style: .continuous)
                                        .strokeBorder(BLColorPrimitives.honey500, lineWidth: 2)
                                )
                                .padding(.horizontal, -8)
                                .padding(.vertical, 1)
                        }
                    }
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.top, 10)
        .padding(.horizontal, 14)
        .padding(.bottom, 6)
        .frame(maxWidth: isSplit ? 390 : 332)
        .background(BLColorPrimitives.paper0)
        .rotationEffect(.degrees(-1.2))
        .shadow(color: Color.black.opacity(0.35), radius: 8, x: 0, y: 3)
    }

    private func handwrittenLineText(_ line: ScannedSheetLinePreview) -> some View {
        let inkColor = BLColorPrimitives.oklch(0.36, 0.12, 265)
        return HStack(spacing: 4) {
            Text(line.handwrittenText)
                .font(.system(size: 15, weight: .semibold, design: .serif).italic())
                .foregroundStyle(inkColor)
            if let overwritten = line.overwrittenDigits, !overwritten.isEmpty {
                Text("(\(overwritten))")
                    .font(.system(size: 11, weight: .bold, design: .serif).italic())
                    .foregroundStyle(BLColorPrimitives.amber700)
            }
        }
    }

    private var sheetDateStamp: String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.calendar = store.profileCalendar
        formatter.timeZone = store.profileTimeZone
        formatter.dateFormat = "EEE M/d"
        return formatter.string(from: sheet.scannedAt)
    }

    // MARK: - Sorted Draft List & Sticky Footer

    private var draftsAndFooterPane: some View {
        VStack(spacing: 0) {
            ScrollViewReader { scrollProxy in
                ScrollView {
                    VStack(alignment: .leading, spacing: BLSpacing.space2) {
                        HStack(alignment: .firstTextBaseline) {
                            Text("\(drafts.count) entries found")
                                .blMicroLabel()
                            Spacer()
                            Text("\(includedCount) selected")
                                .blMicroLabel()
                        }
                        .padding(.top, 14)
                        .padding(.bottom, 4)

                        if let notes = sheet.sheetNotes?.trimmingCharacters(in: .whitespacesAndNewlines),
                           !notes.isEmpty
                        {
                            BLCard(tone: .sunken) {
                                VStack(alignment: .leading, spacing: BLSpacing.space1) {
                                    Text("Sheet notes")
                                        .blMicroLabel()
                                    Text(notes)
                                        .blTextRole(.caption)
                                        .foregroundStyle(theme.textSecondary)
                                }
                            }
                        }

                        if orderedDrafts.isEmpty {
                            BLCard {
                                Text("No entries found on this sheet. Cancel to try another photo.")
                                    .blTextRole(.callout)
                                    .foregroundStyle(theme.textSecondary)
                            }
                        } else {
                            ForEach(orderedDrafts) { draft in
                                let draftTime = FormattingHelpers.formatClock(
                                    draft.effectiveStartedAt,
                                    timeZone: store.profileTimeZone
                                )
                                let needsLook = Self.draftNeedsResolution(draft)
                                let options = resolutionOptions(for: draft, draftTime: draftTime)

                                BLDraftCard(
                                    kind: draft.blEventKind,
                                    time: draftTime,
                                    title: draft.title,
                                    detail: draft.detail,
                                    badgeText: draft.badgeTitle,
                                    badgeTone: draft.blBadgeTone,
                                    isIncluded: draft.isIncluded,
                                    onToggle: { included in
                                        toggleDraft(id: draft.id, isIncluded: included)
                                    },
                                    isSelected: selectedDraftId == draft.id,
                                    onSelect: {
                                        selectedDraftId = draft.id
                                    },
                                    ambiguityQuestion: needsLook ? draft.ambiguityQuestion : nil,
                                    resolutionOptions: needsLook ? options : [],
                                    onResolve: { choice in
                                        resolveAmbiguity(id: draft.id, option: choice)
                                    }
                                )
                                .id(draft.id)
                            }
                        }
                    }
                    .padding(.horizontal, BLSpacing.screenGutter)
                    .padding(.bottom, BLSpacing.space5)
                }
                .scrollIndicators(.hidden)
                .onChange(of: selectedDraftId) { _, newId in
                    guard let newId else { return }
                    withAnimation(.easeOut(duration: BLMotion.base)) {
                        scrollProxy.scrollTo(newId, anchor: .center)
                    }
                }
            }

            // Sticky Save footer
            VStack(spacing: 0) {
                Rectangle()
                    .fill(theme.borderHairline)
                    .frame(height: BLSpacing.borderWidth)

                BLButton(
                    saveButtonLabel,
                    variant: .primary,
                    size: .lg,
                    isBlock: true
                ) {
                    confirmAndSave()
                }
                .disabled(!canSave)
                .padding(.top, BLSpacing.space3)
                .padding(.horizontal, BLSpacing.screenGutter)
                .padding(.bottom, BLSpacing.space5)
            }
            .background(theme.bgApp)
        }
        .background(theme.bgApp)
    }

    // MARK: - Actions & Ambiguity Helpers

    private static func draftHasAmbiguityQuestion(_ draft: ScanReviewDraftItem) -> Bool {
        guard let question = draft.ambiguityQuestion?.trimmingCharacters(in: .whitespacesAndNewlines) else {
            return false
        }
        return !question.isEmpty
    }

    private static func draftNeedsResolution(_ draft: ScanReviewDraftItem) -> Bool {
        guard draft.isIncluded, draft.resolvedOption == nil else { return false }
        return draft.hasUnresolvedAmbiguity || draftHasAmbiguityQuestion(draft)
    }

    private static func sortRank(for draft: ScanReviewDraftItem) -> Int {
        if !draft.ambiguityOptions.isEmpty || draftHasAmbiguityQuestion(draft) {
            return 0
        }
        return draft.reviewSortRank
    }

    private func resolutionOptions(for draft: ScanReviewDraftItem, draftTime: String) -> [String] {
        guard Self.draftNeedsResolution(draft) else { return [] }
        if !draft.ambiguityOptions.isEmpty {
            return draft.ambiguityOptions
        }
        return ["Keep \(draftTime)"]
    }

    private func confirmAndSave() {
        guard canSave else { return }
        isConfirming = true
        let sheetId = sheet.id
        let workingDrafts = drafts
        Task { @MainActor in
            _ = await store.confirmScanReviewAsync(sheetId: sheetId, drafts: workingDrafts)
            isConfirming = false
            onComplete()
        }
    }

    private func toggleDraft(id: String, isIncluded: Bool) {
        guard let idx = drafts.firstIndex(where: { $0.id == id }) else { return }
        drafts[idx].isIncluded = isIncluded
    }

    private func resolveAmbiguity(id: String, option: String) {
        guard let idx = drafts.firstIndex(where: { $0.id == id }) else { return }
        drafts[idx].resolvedOption = option
        if let mappedDate = drafts[idx].ambiguityOptionDates[option] {
            drafts[idx].startedAt = mappedDate
        }
    }

    private func selectDraft(forRowKey rowKey: String) {
        if let matching = orderedDrafts.first(where: { $0.rowKey == rowKey }) {
            selectedDraftId = matching.id
        }
    }

    private func decodePlatformImage(_ data: Data) -> Image? {
        #if canImport(UIKit)
        guard let uiImage = UIImage(data: data) else { return nil }
        return Image(uiImage: uiImage)
        #elseif canImport(AppKit)
        guard let nsImage = NSImage(data: data) else { return nil }
        return Image(nsImage: nsImage)
        #else
        return nil
        #endif
    }
}
