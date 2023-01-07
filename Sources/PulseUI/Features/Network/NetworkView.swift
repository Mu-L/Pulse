// The MIT License (MIT)
//
// Copyright (c) 2020–2023 Alexander Grebenyuk (github.com/kean).

import SwiftUI
import CoreData
import Pulse
import Combine

#if os(iOS) || os(tvOS)

public struct NetworkView: View {
    @ObservedObject var viewModel: NetworkViewModel

    @State private var isShowingFilters = false
    @State private var isSharing = false
    @State private var isShowingAsText = false
    @Environment(\.colorScheme) private var colorScheme: ColorScheme

    public init(store: LoggerStore = .shared) {
        self.viewModel = NetworkViewModel(store: store)
    }

    init(viewModel: NetworkViewModel) {
        self.viewModel = viewModel
    }

    #if os(iOS)
    public var body: some View {
        ConsoleTableView(
            header: { NetworkToolbarView(viewModel: viewModel) },
            viewModel: viewModel.table,
            detailsViewModel: viewModel.details
        )
        .edgesIgnoringSafeArea(.bottom)
        .onAppear(perform: viewModel.onAppear)
        .onDisappear(perform: viewModel.onDisappear)
        .overlay(tableOverlay)
        .navigationBarTitle(Text("Network"))
        .navigationBarItems(
            leading: navigationBarTrailingItems,
            trailing: HStack {
                if #available(iOS 14, *) {
                    ShareButton { isSharing = true }
                    ConsoleContextMenu(store: viewModel.store, isShowingAsText: $isShowingAsText)
                }
            }
        )
        .sheet(isPresented: $isSharing) {
            if #available(iOS 14, *) {
                NavigationView {
                    ShareStoreView(store: viewModel.store, isPresented: $isSharing)
                }.backport.presentationDetents([.medium])
            }
        }
        .backport.fullScreenCover(isPresented: $isShowingAsText) {
            if #available(iOS 14, *) {
                NavigationView {
                    ConsoleTextView(entities: viewModel.getObservableProperties()) {
                        isShowingAsText = false
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var tableOverlay: some View {
        if viewModel.entities.isEmpty {
EmptyView()
        }
    }

    @ViewBuilder
    private var navigationBarTrailingItems: some View {
        if let onDismiss = viewModel.onDismiss {
            Button(action: onDismiss) {
                Image(systemName: "xmark")
            }
        }
    }

    #elseif os(tvOS)
    public var body: some View {
        List {
            NetworkMessagesForEach(entities: viewModel.entities)
        }
        .onAppear(perform: viewModel.onAppear)
        .onDisappear(perform: viewModel.onDisappear)
    }
    #endif
}

#if os(iOS)
private struct NetworkToolbarView: View {
    @ObservedObject var viewModel: NetworkViewModel
    @State private var isShowingFilters = false
    @State private var isSearching = false

    var body: some View {
        VStack {
            HStack(spacing: 0) {
                SearchBar(title: "Search \(viewModel.entities.count) messages", text: $viewModel.filterTerm, isSearching: $isSearching)
                if !isSearching {
                    filters
                } else {
                    Button("Cancel") {
                        isSearching = false
                        viewModel.filterTerm = ""
                    }
                    .foregroundColor(.accentColor)
                    .padding(.horizontal, 14)
                }
            }.buttonStyle(.plain)
        }
        .padding(EdgeInsets(top: 2, leading: 8, bottom: 2, trailing: 8))
        .sheet(isPresented: $isShowingFilters) {
            NavigationView {
                NetworkFiltersView(viewModel: viewModel.searchCriteria, isPresented: $isShowingFilters)
            }
        }
    }

    @ViewBuilder
    private var filters: some View {
        Button(action: { viewModel.isOnlyErrors.toggle() }) {
            Image(systemName: viewModel.isOnlyErrors ? "exclamationmark.octagon.fill" : "exclamationmark.octagon")
                .font(.system(size: 20))
                .foregroundColor(.accentColor)
        }.frame(width: 40, height: 44)
        Button(action: { isShowingFilters = true }) {
            Image(systemName: viewModel.searchCriteria.isDefaultSearchCriteria ? "line.horizontal.3.decrease.circle" : "line.3.horizontal.decrease.circle.fill")
                .font(.system(size: 20))
                .foregroundColor(.accentColor)
        }.frame(width: 40, height: 44)
    }
}
#endif

#if DEBUG
struct NetworkView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationView {
            NetworkView(store: .mock)
        }
    }
}
#endif

#endif
