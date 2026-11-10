#if os(macOS)
import AppKit
import MetrixatorCore
import Observation
import SwiftUI

/// Demande d'ouverture de l'éditeur de résultat (`metricID == nil` : création).
struct EditorRequest: Identifiable, Hashable {
    let id = UUID()
    let metricID: UUID?
}

/// État de navigation de la fenêtre principale.
@Observable
final class Router {
    enum Section: Hashable {
        case dashboard
        case list
    }

    var section: Section? = .dashboard
    /// Pile des vues détaillées (identifiants de résultats).
    var path: [UUID] = []
    /// Décalage de la semaine de référence par rapport à PWK (0 = dernière semaine terminée).
    var weekOffset = 0
    var editor: EditorRequest?
    var showWeeklyEntry = false
    /// Message de la bannière « Annuler ».
    var toast: String?

    func referenceWeek(in store: MetricStore) -> FiscalWeek {
        store.calendar.week(offset: weekOffset, from: store.previousWeek)
    }
}

enum Theme {
    static func dynamic(light: NSColor, dark: NSColor) -> Color {
        Color(nsColor: NSColor(name: nil) { appearance in
            appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua ? dark : light
        })
    }

    /// Fond de fenêtre (gris très clair / quasi noir).
    static let canvas = dynamic(light: NSColor(red: 0.949, green: 0.949, blue: 0.961, alpha: 1),
                                dark: NSColor(white: 0.11, alpha: 1))
    /// Fond des cartes (blanc / gris foncé).
    static let card = dynamic(light: .white, dark: NSColor(white: 0.18, alpha: 1))
    static let cardBorder = dynamic(light: NSColor(white: 0, alpha: 0.06), dark: NSColor(white: 1, alpha: 0.08))
    static let positive = dynamic(light: NSColor(red: 0.13, green: 0.62, blue: 0.29, alpha: 1),
                                  dark: NSColor(red: 0.30, green: 0.82, blue: 0.45, alpha: 1))
    static let negative = dynamic(light: NSColor(red: 0.85, green: 0.20, blue: 0.18, alpha: 1),
                                  dark: NSColor(red: 1.0, green: 0.42, blue: 0.38, alpha: 1))
    static let warning = Color.orange

    static func color(_ c: MetricColor) -> Color {
        let (r, g, b) = c.rgb
        return Color(red: r, green: g, blue: b)
    }

    static func changeColor(_ change: Double?, higherIsBetter: Bool) -> Color {
        guard let change, abs(change) >= 0.05 else { return .secondary }
        return Analytics.isFavorable(change, higherIsBetter: higherIsBetter) ? positive : negative
    }
}

/// Accès à la fenêtre AppKit : retire le trait sous la barre d'outils pour que la colonne
/// de droite forme une seule surface, alignée avec la barre latérale.
struct WindowConfigurator: NSViewRepresentable {
    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        DispatchQueue.main.async { configure(view.window) }
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        DispatchQueue.main.async { configure(nsView.window) }
    }

    private func configure(_ window: NSWindow?) {
        guard let window else { return }
        window.titlebarSeparatorStyle = .none
    }
}

extension View {
    /// Fond de la colonne de droite, prolongé sous sa barre d'outils uniquement.
    /// La barre latérale garde toute la hauteur de la fenêtre (comportement macOS standard) :
    /// on ne peint surtout pas `.windowToolbar`, qui couvrirait aussi le haut de la barre latérale.
    func screenBackground() -> some View {
        self
            .background(Theme.canvas.ignoresSafeArea())
            .modifier(SoftTopScrollEdge())
    }
}

/// macOS 26 : par défaut, une vue défilante sous la barre d'outils reçoit un « scroll edge effect »
/// dur (bande opaque de la couleur de fenêtre, à bord net, qui déborde sur la barre latérale).
/// Le style doux fond le contenu sous la barre d'outils, sans bande d'une autre couleur.
/// Compilé seulement avec le SDK macOS 26 (Xcode 26) ; sans effet sur les versions antérieures.
struct SoftTopScrollEdge: ViewModifier {
    #if compiler(>=6.2)
    @ViewBuilder
    func body(content: Content) -> some View {
        if #available(macOS 26.0, *) {
            content.scrollEdgeEffectStyle(.soft, for: .top)
        } else {
            content
        }
    }
    #else
    func body(content: Content) -> some View { content }
    #endif
}

/// Carte arrondie façon Numerics.
struct CardBackground: ViewModifier {
    var padding: CGFloat = 16

    func body(content: Content) -> some View {
        content
            .padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(Theme.card))
            .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).strokeBorder(Theme.cardBorder))
            .shadow(color: .black.opacity(0.05), radius: 2, y: 1)
    }
}

extension View {
    func card(padding: CGFloat = 16) -> some View { modifier(CardBackground(padding: padding)) }
}

/// Pastille de progression : flèche + valeur + libellé (« ↑ +4,2 % Y/Y »).
struct ChangeBadge: View {
    let change: Double?
    let inPoints: Bool
    let higherIsBetter: Bool
    let label: String
    var font: Font = .subheadline

    var body: some View {
        HStack(spacing: 3) {
            if let change {
                if abs(change) >= 0.05 {
                    Image(systemName: change > 0 ? "arrow.up" : "arrow.down")
                        .font(font.weight(.bold))
                }
                Text(NumberFormat.change(change, inPoints: inPoints))
                    .font(font.weight(.semibold))
                    .monospacedDigit()
            } else {
                Text("—").font(font)
            }
            Text(label)
                .font(font)
                .foregroundStyle(.secondary)
        }
        .foregroundStyle(Theme.changeColor(change, higherIsBetter: higherIsBetter))
        .lineLimit(1)
    }
}

/// Symbole d'alerte avec message (saisie incorrecte, doublon…).
struct WarningLabel: View {
    let message: String

    var body: some View {
        Label(message, systemImage: "exclamationmark.triangle.fill")
            .font(.callout)
            .foregroundStyle(Theme.warning)
            .fixedSize(horizontal: false, vertical: true)
    }
}

/// Icône d'alerte seule, avec infobulle.
struct WarningIcon: View {
    let message: String?

    var body: some View {
        if let message {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(Theme.warning)
                .help(message)
                .accessibilityLabel(message)
        }
    }
}

/// Choix d'une semaine terminée (les 104 dernières).
struct WeekPicker: View {
    let title: String
    @Binding var selection: Day
    let calendar: FiscalCalendar
    let lastWeek: FiscalWeek
    var filled: (Day) -> Bool = { _ in false }

    var weeks: [FiscalWeek] { calendar.trailingWeeks(104, endingAt: lastWeek).reversed() }

    var body: some View {
        Picker(title, selection: $selection) {
            ForEach(weeks, id: \.start) { w in
                Text(L10n.weekLong(w) + (filled(w.start) ? "  ✓" : ""))
                    .tag(w.start)
            }
        }
    }
}
#endif
