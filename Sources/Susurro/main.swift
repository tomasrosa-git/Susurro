import AppKit

let arguments = CommandLine.arguments
if arguments.count > 2, arguments[1] == "--transcribe" {
    exit(await DebugCLI.transcribe(path: arguments[2]))
}
if arguments.count > 2, arguments[1] == "--command" {
    exit(await DebugCLI.command(arguments[2], selection: arguments.count > 3 ? arguments[3] : nil))
}
if arguments.count > 2, arguments[1] == "--clean" {
    exit(await DebugCLI.clean(arguments[2]))
}

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.setActivationPolicy(.accessory)
app.run()
