#if DEBUG

import SwiftUI
import SixthSeat

/// Hidden developer affordance from Session 18c. Accessed via a
/// long-press on the Main Menu title — never surfaced through any
/// production navigation path. The whole file is wrapped in
/// `#if DEBUG`, so it doesn't compile into Release.
///
/// Tapping a scenario writes the choice into `DebugDealForcer
/// .pendingScenario`. The next time `GameTableViewModel.deal()` runs,
/// it consumes that buffer and swaps the engine's deck for the forced
/// 9-card sequence — one hand only; subsequent hands draw normally.
struct DebugMenuView: View {

    @Binding var isPresented: Bool

    /// Mirror of `DebugDealForcer.pendingScenario` so the "armed"
    /// section updates when the user taps a scenario. Reads the static
    /// at appear time and on every write the view performs.
    @State private var armed: DebugScenario?

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    ForEach(DebugScenario.allCases, id: \.self) { scenario in
                        Button {
                            arm(scenario)
                        } label: {
                            HStack {
                                Text(scenario.displayName)
                                    .foregroundStyle(.primary)
                                Spacer()
                                if armed == scenario {
                                    Text("ARMED")
                                        .font(.system(size: 11, weight: .bold))
                                        .foregroundStyle(.yellow)
                                }
                            }
                        }
                        .accessibilityIdentifier("DebugMenu.\(scenario.rawValue)")
                    }
                } header: {
                    Text("Force the next deal")
                } footer: {
                    Text("One-shot. The forced cards are consumed by the next DEAL, then the deck returns to normal random play.")
                }

                if armed != nil {
                    Section {
                        Button("Clear armed scenario", role: .destructive) {
                            arm(nil)
                        }
                        .accessibilityIdentifier("DebugMenu.Clear")
                    }
                }

                Section {
                    Text("Debug menu is compiled in DEBUG builds only. Hidden from production by `#if DEBUG`. Access: long-press the Main Menu title.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                } header: {
                    Text("About")
                }
            }
            .navigationTitle("Debug Menu")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { isPresented = false }
                        .accessibilityIdentifier("DebugMenu.Done")
                }
            }
            .onAppear {
                armed = DebugDealForcer.pendingScenario
            }
        }
    }

    private func arm(_ scenario: DebugScenario?) {
        DebugDealForcer.pendingScenario = scenario
        armed = scenario
    }
}

#Preview {
    DebugMenuView(isPresented: .constant(true))
}

#endif
