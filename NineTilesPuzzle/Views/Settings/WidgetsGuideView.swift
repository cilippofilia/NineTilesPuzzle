//
//  WidgetsGuideView.swift
//  NineTilesPuzzle
//
//  Created by Filippo Cilia on 7/6/26.
//

import SwiftUI

struct WidgetsGuideView: View {
    var body: some View {
        List {
            Section {
                WidgetGuideStepRow(number: 1, text: "Go to your Home Screen and touch and hold an empty area until the apps begin to jiggle.")
                WidgetGuideStepRow(number: 2, text: "Tap Edit in the top-left corner, then choose Add Widget.")
                WidgetGuideStepRow(number: 3, text: "Search for Nine Tiles Puzzle.")
                WidgetGuideStepRow(number: 4, text: "Swipe to choose a widget and size, then tap Add Widget.")
                WidgetGuideStepRow(number: 5, text: "Tap Done in the top-right corner.")
            } header: {
                Text("Add a Widget")
            } footer: {
                Text("You can also touch and hold the Nine Tiles Puzzle app icon on your Home Screen and pick a widget straight from the menu that appears.")
            }

            Section("Available Widgets") {
                WidgetGuideWidgetRow(
                    icon: "calendar",
                    color: .orange,
                    name: "Daily Challenge",
                    description: "Today's puzzle at a glance — mode, grid size, and your calendar streak."
                )
            }
        }
        .navigationTitle("Widgets")
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct WidgetGuideStepRow: View {
    let number: Int
    let text: String

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(number, format: .number)
                .bold()
                .monospacedDigit()
                .foregroundStyle(.tint)

            Text(text)
        }
    }
}

struct WidgetGuideWidgetRow: View {
    let icon: String
    let color: Color
    let name: String
    let description: String

    var body: some View {
        Label {
            VStack(alignment: .leading) {
                Text(name)

                Text(description)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        } icon: {
            Image(systemName: icon)
                .foregroundStyle(color)
        }
    }
}

#Preview {
    NavigationStack {
        WidgetsGuideView()
    }
}
