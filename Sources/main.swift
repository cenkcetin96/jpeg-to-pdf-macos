import AppKit
import SwiftUI
import UniformTypeIdentifiers
import ImageIO
import PDFKit

struct ConvertedImage {
    let pdf: Data
    let thumbnail: NSImage
    let width: Int
    let height: Int
}

func convertJPEG(_ url: URL) throws -> ConvertedImage {
    guard let source = CGImageSourceCreateWithURL(url as CFURL, nil),
          let type = CGImageSourceGetType(source), UTType(type as String)?.conforms(to: .jpeg) == true,
          let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any],
          let width = properties[kCGImagePropertyPixelWidth] as? Int,
          let height = properties[kCGImagePropertyPixelHeight] as? Int else {
        throw NSError(domain: "PaperPDF", code: 1, userInfo: [NSLocalizedDescriptionKey: "This file is not a readable JPEG."])
    }
    let options: [CFString: Any] = [
        kCGImageSourceCreateThumbnailFromImageAlways: true,
        kCGImageSourceCreateThumbnailWithTransform: true,
        kCGImageSourceThumbnailMaxPixelSize: max(width, height)
    ]
    guard let image = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary) else {
        throw NSError(domain: "PaperPDF", code: 2, userInfo: [NSLocalizedDescriptionKey: "Could not decode this image."])
    }
    let data = NSMutableData()
    let scale = min(0.75, 14400.0 / Double(max(image.width, image.height)))
    var bounds = CGRect(x: 0, y: 0, width: Double(image.width) * scale, height: Double(image.height) * scale)
    guard let consumer = CGDataConsumer(data: data as CFMutableData),
          let context = CGContext(consumer: consumer, mediaBox: &bounds, nil) else {
        throw NSError(domain: "PaperPDF", code: 3, userInfo: [NSLocalizedDescriptionKey: "Could not create the PDF."])
    }
    context.beginPDFPage(nil)
    context.draw(image, in: bounds)
    context.endPDFPage()
    context.closePDF()
    var previewOptions = options
    previewOptions[kCGImageSourceThumbnailMaxPixelSize] = 160
    let preview = CGImageSourceCreateThumbnailAtIndex(source, 0, previewOptions as CFDictionary) ?? image
    return ConvertedImage(pdf: data as Data, thumbnail: NSImage(cgImage: preview, size: .zero), width: image.width, height: image.height)
}

struct ImageItem: Identifiable {
    let id = UUID()
    let url: URL
    var result: ConvertedImage?
    var error: String?
}

final class Converter: ObservableObject {
    @Published var items: [ImageItem] = []
    @Published var message = ""
    private let worker = DispatchQueue(label: "local.paperpdf.converter", qos: .userInitiated)

    func chooseImages() {
        let panel = NSOpenPanel()
        panel.title = "Choose JPEG images"
        panel.allowedContentTypes = [.jpeg]
        panel.allowsMultipleSelection = true
        panel.canChooseDirectories = false
        if panel.runModal() == .OK { add(panel.urls) }
    }

    func add(_ urls: [URL]) {
        message = ""
        for url in urls {
            let item = ImageItem(url: url)
            items.append(item)
            worker.async {
                guard DispatchQueue.main.sync(execute: { self.items.contains(where: { $0.id == item.id }) }) else { return }
                let result: Result<ConvertedImage, Error> = autoreleasepool { Result { try convertJPEG(url) } }
                DispatchQueue.main.async {
                    guard let index = self.items.firstIndex(where: { $0.id == item.id }) else { return }
                    switch result {
                    case .success(let converted): self.items[index].result = converted
                    case .failure(let error): self.items[index].error = error.localizedDescription
                    }
                }
            }
        }
    }

    func export(_ item: ImageItem) {
        guard let result = item.result else { return }
        let panel = NSSavePanel()
        panel.title = "Export PDF"
        panel.allowedContentTypes = [.pdf]
        panel.nameFieldStringValue = item.url.deletingPathExtension().lastPathComponent + ".pdf"
        panel.canCreateDirectories = true
        if panel.runModal() == .OK, let url = panel.url {
            do {
                try result.pdf.write(to: url, options: .atomic)
                message = "Saved \(url.lastPathComponent)"
            } catch {
                let alert = NSAlert(error: error)
                alert.runModal()
            }
        }
    }
}

struct ContentView: View {
    @ObservedObject var model: Converter
    @State private var targeted = false
    let green = Color(red: 0.15, green: 0.36, blue: 0.28)

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack {
                Label("paper.", systemImage: "doc.richtext").font(.system(size: 23, weight: .bold))
                Spacer()
                Label("On your Mac. Always private.", systemImage: "lock.shield").font(.caption).foregroundStyle(.secondary)
            }
            VStack(alignment: .leading, spacing: 8) {
                Text("JPEGs in. PDFs out.").font(.system(size: 34, weight: .semibold))
                Text("Add several images. Export each as its own PDF.").foregroundStyle(.secondary)
            }
            VStack(spacing: 12) {
                Image(systemName: "square.and.arrow.up").font(.system(size: 28)).foregroundStyle(green)
                Text("Drop JPEG images here").font(.headline)
                Button("Choose images…") { model.chooseImages() }.keyboardShortcut("o").buttonStyle(.borderedProminent).tint(green)
                Text("JPG & JPEG · Multiple files welcome").font(.caption).foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity).padding(24)
            .background(targeted ? green.opacity(0.16) : green.opacity(0.05))
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(green.opacity(0.3), style: StrokeStyle(lineWidth: 1, dash: [5])))
            .onDrop(of: [UTType.fileURL.identifier], isTargeted: $targeted) { providers in
                for provider in providers {
                    provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier, options: nil) { value, _ in
                        let url: URL?
                        if let data = value as? Data { url = URL(dataRepresentation: data, relativeTo: nil) }
                        else { url = value as? URL }
                        if let url = url { DispatchQueue.main.async { model.add([url]) } }
                    }
                }
                return true
            }
            HStack {
                Text("Your files").font(.headline)
                Text("\(model.items.count)").font(.caption).foregroundStyle(.secondary)
                Spacer()
                if !model.items.isEmpty { Button("Clear all") { model.items.removeAll(); model.message = "" }.buttonStyle(.plain).foregroundStyle(.secondary) }
            }
            if model.items.isEmpty {
                VStack(spacing: 9) {
                    Image(systemName: "photo.on.rectangle.angled").font(.title).foregroundStyle(.tertiary)
                    Text("Your images will appear here.").foregroundStyle(.secondary)
                }.frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVStack(spacing: 8) {
                        ForEach(model.items) { item in
                            HStack(spacing: 12) {
                                Group {
                                    if let result = item.result { Image(nsImage: result.thumbnail).resizable().scaledToFit() }
                                    else { Image(systemName: "photo").foregroundStyle(.secondary) }
                                }.frame(width: 54, height: 62).background(Color.primary.opacity(0.04)).clipShape(RoundedRectangle(cornerRadius: 5))
                                VStack(alignment: .leading, spacing: 5) {
                                    Text(item.url.lastPathComponent).font(.system(size: 13, weight: .medium)).lineLimit(1).help(item.url.lastPathComponent)
                                    if let result = item.result {
                                        Text("\(result.width) × \(result.height) px · \(ByteCountFormatter.string(fromByteCount: Int64(result.pdf.count), countStyle: .file)) PDF").font(.caption).foregroundStyle(.secondary)
                                    } else if let error = item.error {
                                        Text(error).font(.caption).foregroundStyle(.red)
                                    } else { Text("Converting…").font(.caption).foregroundStyle(.secondary) }
                                }
                                Spacer(minLength: 8)
                                if item.result != nil { Button("Export PDF…") { model.export(item) } }
                                Button { model.items.removeAll { $0.id == item.id } } label: { Image(systemName: "xmark").font(.caption) }.buttonStyle(.plain).foregroundStyle(.secondary).help("Remove \(item.url.lastPathComponent)")
                            }.padding(10).background(Color(NSColor.controlBackgroundColor)).clipShape(RoundedRectangle(cornerRadius: 9))
                        }
                    }
                }
            }
            HStack {
                Text(model.message.isEmpty ? "One image, one PDF. Works completely offline." : model.message)
                Spacer()
                Text("Close the window to keep Paper in the menu bar.")
            }.font(.system(size: 10)).foregroundStyle(.secondary)
        }
        .padding(28).frame(minWidth: 640, minHeight: 640)
        .background(Color(NSColor.windowBackgroundColor))
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate, NSWindowDelegate {
    let converter = Converter()
    var window: NSWindow!
    var statusItem: NSStatusItem!

    func applicationDidFinishLaunching(_ notification: Notification) {
        let mainMenu = NSMenu()
        let appItem = NSMenuItem()
        let appMenu = NSMenu()
        appMenu.addItem(withTitle: "About Paper PDF", action: #selector(about), keyEquivalent: "")
        appMenu.addItem(.separator())
        appMenu.addItem(withTitle: "Hide Paper PDF", action: #selector(NSApplication.hide(_:)), keyEquivalent: "h")
        appMenu.addItem(withTitle: "Quit Paper PDF", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        appItem.submenu = appMenu
        mainMenu.addItem(appItem)
        let fileItem = NSMenuItem()
        let fileMenu = NSMenu(title: "File")
        fileMenu.addItem(withTitle: "Add JPEG Images…", action: #selector(addImages), keyEquivalent: "o")
        fileMenu.addItem(withTitle: "Close Window", action: #selector(NSWindow.performClose(_:)), keyEquivalent: "w")
        fileItem.submenu = fileMenu
        mainMenu.addItem(fileItem)
        let editItem = NSMenuItem()
        let editMenu = NSMenu(title: "Edit")
        for (title, action, key) in [("Cut", "cut:", "x"), ("Copy", "copy:", "c"), ("Paste", "paste:", "v"), ("Select All", "selectAll:", "a")] {
            editMenu.addItem(withTitle: title, action: Selector(action), keyEquivalent: key)
        }
        editItem.submenu = editMenu
        mainMenu.addItem(editItem)
        NSApp.mainMenu = mainMenu

        window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 800, height: 800), styleMask: [.titled, .closable, .miniaturizable, .resizable], backing: .buffered, defer: false)
        window.title = "Paper PDF"
        window.isReleasedWhenClosed = false
        window.delegate = self
        window.contentView = NSHostingView(rootView: ContentView(model: converter))
        window.center()
        window.setFrameAutosaveName("PaperPDFWindow")

        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        statusItem.button?.image = NSImage(systemSymbolName: "doc.richtext", accessibilityDescription: "Paper PDF")
        statusItem.button?.toolTip = "Paper PDF — JPEG to PDF"
        let menu = NSMenu()
        menu.addItem(withTitle: "Open Paper PDF", action: #selector(showWindow), keyEquivalent: "")
        menu.addItem(withTitle: "Add JPEG Images…", action: #selector(addImages), keyEquivalent: "")
        menu.addItem(.separator())
        menu.addItem(withTitle: "Quit Paper PDF", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "")
        statusItem.menu = menu
        showWindow()
    }
    @objc func showWindow() { window.makeKeyAndOrderFront(nil); NSApp.activate(ignoringOtherApps: true) }
    @objc func addImages() { showWindow(); converter.chooseImages() }
    @objc func about() { NSApp.orderFrontStandardAboutPanel(nil) }
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { false }
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool { showWindow(); return true }
    func application(_ sender: NSApplication, open urls: [URL]) { showWindow(); converter.add(urls) }
}

if CommandLine.arguments.count > 2 && CommandLine.arguments[1] == "--self-test" {
    do {
        for path in CommandLine.arguments.dropFirst(2) {
            let url = URL(fileURLWithPath: path)
            let result = try convertJPEG(url)
            guard let pdf = PDFDocument(data: result.pdf), pdf.pageCount == 1,
                  let page = pdf.page(at: 0) else { fatalError("Invalid PDF") }
            let rect = page.bounds(for: .mediaBox)
            let scale = min(0.75, 14400.0 / Double(max(result.width, result.height)))
            precondition(abs(rect.width - Double(result.width) * scale) < 0.1)
            precondition(abs(rect.height - Double(result.height) * scale) < 0.1)
            print("PASS \(url.lastPathComponent): \(result.width)×\(result.height), single-page PDF \(result.pdf.count) bytes")
        }
        exit(0)
    } catch { fputs("\(error.localizedDescription)\n", stderr); exit(1) }
}
let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.setActivationPolicy(.regular)
app.run()
