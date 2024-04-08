//
//  QuickFilterView.swift
//  Mastonaut
//
//  Created by Sören Kuklau on 07.04.24.
//

import SwiftUI
import Throttler

enum QuickFilterCategory: Hashable {
    case everything
    case noBoosts
    case media
    case links
}

struct QuickFilterView: View {
    @State
    var selectedCategory: QuickFilterCategory

    @State
    var query: String

    var timelineController: TimelineViewController?

    var body: some View {
        VStack {
            Picker("", selection: $selectedCategory) {
                Image(systemName: "books.vertical").tag(QuickFilterCategory.everything).help("Everything")
                Image("boost.slash").tag(QuickFilterCategory.noBoosts).help("No boosts")
                Image(systemName: "photo.on.rectangle").tag(QuickFilterCategory.media).help("Just media")
                Image(systemName: "safari").tag(QuickFilterCategory.links).help("Just links")
            }
            .pickerStyle(.segmented)
            .labelsHidden()

            HStack {
                Image(systemName: "magnifyingglass")
                TextField("Search", text: $query)
            }
            .padding(.top, 1)
        }
        .frame(width: 300, height: 40)
        .padding(.all, 20)
        .onChange(of: selectedCategory) {
            newCategory in

            timelineController?.applyQuickFilterCategory(category: newCategory)
        }
        .onChange(of: query) {
            _ in

            throttle(seconds: 0.1) {
                timelineController?.applyQuickFilterQuery(query: query)
            }
        }
    }
}

#Preview {
    VStack {
        QuickFilterView(selectedCategory: QuickFilterCategory.everything, query: "")
        QuickFilterView(selectedCategory: QuickFilterCategory.media, query: "Hello")
    }
}