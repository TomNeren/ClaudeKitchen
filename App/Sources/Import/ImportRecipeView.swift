import KitchenCore
import PDFKit
import SwiftUI
import UniformTypeIdentifiers

/// Sheet for turning any recipe into an Omni Cook recipe with Claude.
struct ImportRecipeView: View {
    @State private var model: ImportRecipeModel
    @Environment(\.dismiss) private var dismiss
    /// Claude's recipe open in the editor, before anything is saved.
    @State private var editing: Recipe?
    @State private var savedFromEditor = false
    @State private var choosingPDF = false
    private let onSaved: @MainActor () -> Void

    init(model: ImportRecipeModel = ImportRecipeModel(), onSaved: @escaping @MainActor () -> Void) {
        self.model = model
        self.onSaved = onSaved
    }

    var body: some View {
        NavigationStack {
            content
                .navigationTitle("Rezept importieren")
                .toolbarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Abbrechen", role: .cancel) { dismiss() }
                    }
                    ToolbarItem(placement: .confirmationAction) { primaryAction }
                    if case .preview = model.phase {
                        ToolbarItem(placement: .bottomBar) {
                            Button("Zurück zum Text", systemImage: "text.alignleft") { model.edit() }
                        }
                        ToolbarSpacer(.flexible, placement: .bottomBar)
                        ToolbarItem(placement: .bottomBar) {
                            Button("Bearbeiten", systemImage: "pencil") { editing = model.previewRecipe }
                        }
                    }
                }
        }
        // Sichern in the editor stores the recipe; once the editor is gone, the import closes too.
        .sheet(item: $editing, onDismiss: finishIfSaved) { recipe in
            RecipeEditorView(recipe: recipe, isNew: true, title: "Import bearbeiten", profile: model.profile) {
                edited in
                let saved = await model.saveEdited(edited)
                if saved { savedFromEditor = true }
                return saved
            }
        }
        .fileImporter(isPresented: $choosingPDF, allowedContentTypes: [.pdf]) { result in
            if case .success(let url) = result { model.openPDF(at: url) }
        }
        .onAppear { model.refreshKey() }
        // Closing the sheet stops a running conversion, so no paid request runs on unseen.
        .onDisappear { model.cancel() }
    }

    @ViewBuilder
    private var content: some View {
        switch model.phase {
        case .editing:
            EditingForm(
                text: $model.text, link: $model.link, hasKey: model.hasKey, linkIsInsecure: model.linkIsInsecure,
                textOrigin: model.textOrigin
            ) {
                PDFSection(
                    pdf: model.pdf, canRead: model.canReadPDF, choose: { choosingPDF = true },
                    toggle: model.togglePage, read: model.readPDF, close: model.closePDF)
            }
        case .working(let label):
            ProgressView(label)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        case .preview(let recipe, let issues):
            ImportPreview(recipe: recipe, issues: issues)
        case .saved:
            ContentUnavailableView {
                Label("Gespeichert", systemImage: "checkmark.circle")
            } description: {
                Text("Das Rezept steht oben in der Bibliothek.")
            } actions: {
                Button("Fertig") { finish() }
            }
        case .failed(let message):
            ContentUnavailableView {
                Label("Import nicht möglich", systemImage: "exclamationmark.triangle")
            } description: {
                Text(message)
            } actions: {
                Button("Zurück zum Text") { model.edit() }
            }
        }
    }

    private func finishIfSaved() {
        if savedFromEditor { finish() }
    }

    private func finish() {
        onSaved()
        dismiss()
    }

    @ViewBuilder
    private var primaryAction: some View {
        switch model.phase {
        case .saved:
            Button("Fertig") { finish() }
        case .preview:
            Button("Speichern") {
                Task {
                    if await model.save() {
                        onSaved()
                        dismiss()
                    }
                }
            }
            .disabled(!model.canSave)
        default:
            Button("Umwandeln") { model.convert() }
                .disabled(!model.canConvert)
        }
    }
}

private struct EditingForm<PDFContent: View>: View {
    @Binding var text: String
    @Binding var link: String
    let hasKey: Bool
    let linkIsInsecure: Bool
    let textOrigin: ScannedText.Source?
    @ViewBuilder let pdfSection: PDFContent

    var body: some View {
        Form {
            if !hasKey {
                Section {
                    Label(
                        "Für den Import brauchst du einen API-Schlüssel von Anthropic. Trag ihn in den Einstellungen ein.",
                        systemImage: "key")
                }
            }
            Section("Link") {
                TextField("https://…", text: $link)
                    .keyboardType(.URL)
                    .textContentType(.URL)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                if linkIsInsecure {
                    Text("Nur https-Links lassen sich laden.")
                        .font(.footnote)
                        .foregroundStyle(Palette.accent)
                }
            }
            pdfSection
            Section {
                TextEditor(text: $text)
                    .frame(minHeight: 240)
            } header: {
                Text("Oder Rezepttext")
            } footer: {
                switch textOrigin {
                case .textLayer:
                    Text("Aus der Textschicht der PDF gelesen. Schau kurz drüber, bevor du umwandelst.")
                case .recognition:
                    Text(
                        "Per Texterkennung vom Scan gelesen. Prüf vor allem Mengen und Zahlen, bevor du umwandelst.")
                case nil:
                    Text(
                        "Zutaten und Zubereitung, zum Beispiel aus einer Website oder einem Kochbuch kopiert. Claude rechnet die Schritte auf den Omni Cook um; vor dem Speichern prüft die App alle Werte."
                    )
                }
            }
        }
    }
}

/// A PDF as the third source: pick a file, choose the recipe's pages, read their text into the editor.
private struct PDFSection: View {
    let pdf: PDFSource?
    let canRead: Bool
    let choose: () -> Void
    let toggle: (Int) -> Void
    let read: () -> Void
    let close: () -> Void

    var body: some View {
        Section {
            if let pdf {
                HStack {
                    Label(pdf.name, systemImage: "doc.richtext")
                        .lineLimit(1)
                    Spacer()
                    Button("PDF entfernen", systemImage: "xmark.circle.fill", action: close)
                        .labelStyle(.iconOnly)
                        .foregroundStyle(.secondary)
                }
                if pdf.selection.pageCount > 1 {
                    PageStrip(pdf: pdf, toggle: toggle)
                }
                Button("Text übernehmen", systemImage: "text.viewfinder", action: read)
                    .disabled(!canRead)
            } else {
                Button("PDF wählen", systemImage: "doc.badge.plus", action: choose)
            }
        } header: {
            Text("Oder PDF-Seite")
        } footer: {
            if let pdf, pdf.selection.pageCount > 1 {
                Text(
                    "Tipp auf die Seiten mit dem Rezept, höchstens \(PageSelection.maximum). Ohne brauchbare Textschicht erkennt das iPhone den Text selbst."
                )
            } else {
                Text("Zum Beispiel ein eingescanntes Kochbuch. Der Text bleibt auf dem Gerät, bis du umwandelst.")
            }
        }
    }
}

/// The pages of the PDF as thumbnails to tap, with a field to jump in long scans.
private struct PageStrip: View {
    let pdf: PDFSource
    let toggle: (Int) -> Void
    @State private var jump = ""
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView(.horizontal) {
                LazyHStack(spacing: 12) {
                    ForEach(0..<pdf.selection.pageCount, id: \.self) { index in
                        Button {
                            toggle(index)
                        } label: {
                            PageThumbnail(
                                document: pdf.document, index: index, label: pdf.label(of: index),
                                isSelected: pdf.selection.contains(index))
                        }
                        .buttonStyle(.plain)
                        .disabled(!pdf.selection.contains(index) && pdf.selection.isFull)
                        .id(index)
                    }
                }
                .padding(.vertical, 4)
            }
            .scrollIndicators(.hidden)
            .frame(height: 190)
            if pdf.selection.pageCount > 8 {
                TextField("Zu Seite springen", text: $jump)
                    .keyboardType(.numberPad)
                    .onSubmit { scroll(proxy) }
                    .onChange(of: jump) { scroll(proxy) }
            }
        }
    }

    /// Jumps to the page whose printed label or position matches the typed number.
    private func scroll(_ proxy: ScrollViewProxy) {
        let wanted = jump.trimmingCharacters(in: .whitespaces)
        guard !wanted.isEmpty else { return }
        let target =
            (0..<pdf.selection.pageCount).first { pdf.label(of: $0) == wanted }
            ?? Int(wanted).map { $0 - 1 }.flatMap { (0..<pdf.selection.pageCount).contains($0) ? $0 : nil }
        guard let target else { return }
        withAnimation(reduceMotion ? nil : Motion.pageJump) { proxy.scrollTo(target, anchor: .center) }
    }
}

private struct PageThumbnail: View {
    let document: PDFDocument
    let index: Int
    let label: String
    let isSelected: Bool
    @State private var image: UIImage?

    var body: some View {
        VStack(spacing: 6) {
            ZStack(alignment: .topTrailing) {
                Group {
                    if let image {
                        Image(uiImage: image).resizable().scaledToFit()
                    } else {
                        Rectangle().fill(.quaternary)
                    }
                }
                .frame(width: 110, height: 150)
                .clipShape(.rect(cornerRadius: 6))
                .overlay {
                    RoundedRectangle(cornerRadius: 6)
                        .strokeBorder(
                            isSelected ? Palette.accent : Color.secondary.opacity(0.3), lineWidth: isSelected ? 3 : 1)
                }
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.title2)
                        .foregroundStyle(.white, Palette.accent)
                        .padding(6)
                }
            }
            Text("S. \(label)")
                .font(.caption.weight(isSelected ? .semibold : .regular))
                .monospacedDigit()
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Seite \(label)")
        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
        .task(id: index) {
            image = document.page(at: index)?.thumbnail(of: CGSize(width: 220, height: 300), for: .cropBox)
        }
    }
}

/// What Claude made of the recipe, with the device check, before anything is saved.
private struct ImportPreview: View {
    let recipe: Recipe
    let issues: [ValidationIssue]

    private var blocksSaving: Bool { issues.contains { $0.severity == .error } }

    var body: some View {
        List {
            Section {
                VStack(alignment: .leading, spacing: 4) {
                    Text(recipe.tag.uppercased())
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Palette.accent)
                    Text(recipe.name)
                        .font(.title2.weight(.semibold))
                        .fontDesign(.serif)
                    Text(
                        "≈ \(recipe.totalMinutes) Min · \(Portions.text(recipe.baseServings)) · \(recipe.steps.count) Schritte"
                    )
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                }
            }
            if !issues.isEmpty {
                Section {
                    ForEach(issues, id: \.self) { issue in
                        Label(
                            IssueText.text(for: issue, in: recipe),
                            systemImage: issue.severity == .error
                                ? "xmark.octagon.fill" : "exclamationmark.triangle.fill"
                        )
                        .foregroundStyle(issue.severity == .error ? Color.red : Palette.accent)
                    }
                } header: {
                    Text("Prüfung")
                } footer: {
                    if blocksSaving {
                        Text(
                            "So lässt es sich nicht speichern. Über „Bearbeiten“ unten korrigierst du die Werte direkt."
                        )
                    }
                }
            }
            Section("Zutaten") {
                ForEach(recipe.ingredients) { ingredient in
                    HStack {
                        Text(ingredient.name)
                        Spacer()
                        Text(AmountFormatter.string(for: ingredient.amount))
                            .foregroundStyle(.secondary)
                            .monospacedDigit()
                    }
                }
            }
            Section("Ablauf") {
                ForEach(Array(recipe.steps.enumerated()), id: \.element.id) { index, step in
                    VStack(alignment: .leading, spacing: 4) {
                        Text("\(index + 1). \(step.phase)")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(Palette.accent)
                        Text(step.text)
                        if let parts = step.setting.map(SettingFormatter.parts(of:)), !parts.isEmpty {
                            Text(parts.joined(separator: " · "))
                                .font(.subheadline.weight(.medium))
                                .foregroundStyle(Palette.herb)
                                .monospacedDigit()
                        }
                    }
                    .accessibilityElement(children: .combine)
                }
            }
        }
    }
}

#Preview("Eingabe") {
    ImportRecipeView(model: ImportRecipeModel(hasKey: true)) {}
}

#Preview("Vorschau") {
    if let recipe = Recipe.fixtures.first {
        NavigationStack {
            ImportPreview(
                recipe: recipe, issues: DeviceProfile.omniCook.validate(recipe, servings: 12))
        }
    }
}
