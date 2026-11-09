#if !os(macOS)
// L'interface est réservée à macOS. Sur les autres plateformes (CI Linux), on ne compile
// que la logique métier ; cet exécutable se contente d'afficher un message.
@main
struct MetrixatorLinuxStub {
    static func main() {
        print("Metrixator est une app macOS. Lancez `swift test` pour tester la logique métier.")
    }
}
#endif
