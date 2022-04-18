// The MIT License (MIT)
//
// Copyright (c) 2020–2022 Alexander Grebenyuk (github.com/kean).

import CoreData
import PulseCore
import Combine
import SwiftUI

@available(iOS 13.0, tvOS 14.0, watchOS 7.0, *)
final class NetworkViewModel: NSObject, NSFetchedResultsControllerDelegate, ObservableObject {
    @Published private(set) var entities: AnyCollection<LoggerNetworkRequestEntity> = AnyCollection([])

    // Search criteria
    let searchCriteria: NetworkSearchCriteriaViewModel
    @Published var filterTerm: String = ""
    // TODO: implement quick filters
    // @Published private(set) var quickFilters: [QuickFilterViewModel] = []

    // TODO: get DI right, this is a quick workaround to fix @EnvironmentObject crashes
    var context: AppContext { .init(store: store) }

    private let store: LoggerStore
    private let controller: NSFetchedResultsController<LoggerNetworkRequestEntity>
    private var latestSessionId: String?
    private var cancellables = [AnyCancellable]()

    init(store: LoggerStore) {
        self.store = store

        let request = NSFetchRequest<LoggerNetworkRequestEntity>(entityName: "\(LoggerNetworkRequestEntity.self)")
        request.fetchBatchSize = 250
        request.sortDescriptors = [NSSortDescriptor(keyPath: \LoggerNetworkRequestEntity.createdAt, ascending: true)]

        self.controller = NSFetchedResultsController<LoggerNetworkRequestEntity>(fetchRequest: request, managedObjectContext: store.container.viewContext, sectionNameKeyPath: nil, cacheName: nil)

        self.searchCriteria = NetworkSearchCriteriaViewModel(isDefaultStore: store === LoggerStore.default)

        super.init()

        controller.delegate = self

        $filterTerm.throttle(for: 0.33, scheduler: RunLoop.main, latest: true).dropFirst().sink { [weak self] filterTerm in
            self?.refresh(filterTerm: filterTerm)
        }.store(in: &cancellables)

        searchCriteria.dataNeedsReload.throttle(for: 0.5, scheduler: DispatchQueue.main, latest: true).sink { [weak self] in
            self?.refreshNow()
        }.store(in: &cancellables)

        refreshNow()

        store.backgroundContext.perform {
            self.getAllDomains()
        }
    }

    // MARK: Refresh

    private func refreshNow() {
        refresh(filterTerm: filterTerm)
    }

    private func refresh(filterTerm: String) {
        // Get sessionId
        if latestSessionId == nil {
            latestSessionId = entities.first?.session
        }
        let sessionId = store === LoggerStore.default ? LoggerSession.current.id.uuidString : latestSessionId

        // Search messages
        NetworkSearchCriteria.update(request: controller.fetchRequest, filterTerm: filterTerm, criteria: searchCriteria.criteria, filters: searchCriteria.filters, isOnlyErrors: false, sessionId: sessionId)
        try? controller.performFetch()

        self.didRefreshEntities()
    }

    // MARK: - NSFetchedResultsControllerDelegate

    // This never gets called on macOS
    func controllerDidChangeContent(_ controller: NSFetchedResultsController<NSFetchRequestResult>) {
        self.didRefreshEntities()
    }

    func controller(_ controller: NSFetchedResultsController<NSFetchRequestResult>, didChange anObject: Any, at indexPath: IndexPath?, for type: NSFetchedResultsChangeType, newIndexPath: IndexPath?) {
        switch type {
        case .insert:
            if let entity = anObject as? LoggerNetworkRequestEntity {
                searchCriteria.didInsertEntity(entity)
            }
        default:
            break
        }
    }

    private func didRefreshEntities() {
        var entities: AnyCollection<LoggerNetworkRequestEntity>

        // Apply filters that couldn't be done programmatically
        if let filters = searchCriteria.programmaticFilters {
            let objects = controller.fetchedObjects ?? []
            entities = AnyCollection(objects.filter { evaluateProgrammaticFilters(filters, entity: $0, store: store) })
        } else {
            entities = AnyCollection(FetchedObjects(controller: controller))
        }

        self.entities = entities
    }

    // MARK: - Misc

    private func getAllDomains() {
        let fetchRequest = NSFetchRequest<NSFetchRequestResult>(entityName: "\(LoggerNetworkRequestEntity.self)")

        // Required! Unless you set the resultType to NSDictionaryResultType, distinct can't work.
        // All objects in the backing store are implicitly distinct, but two dictionaries can be duplicates.
        // Since you only want distinct names, only ask for the 'name' property.
        fetchRequest.resultType = .dictionaryResultType
        fetchRequest.propertiesToFetch = ["host"]
        fetchRequest.returnsDistinctResults = true

        // Now it should yield an NSArray of distinct values in dictionaries.
        let map = (try? store.backgroundContext.fetch(fetchRequest)) ?? []
        let values = (map as? [[String: String]])?.compactMap { $0["host"] }
        let set = Set(values ?? [])

        DispatchQueue.main.async {
            self.searchCriteria.setInitialDomains(set)
        }
    }
}
