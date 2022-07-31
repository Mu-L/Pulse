// The MIT License (MIT)
//
// Copyright (c) 2020–2022 Alexander Grebenyuk (github.com/kean).

import Foundation
import Combine
import PulseCore
import SwiftUI

#if swift(>=5.7)
import Charts
#endif

#if os(iOS)

public struct NetworkInsightsView: View {
    @ObservedObject var viewModel: NetworkInsightsViewModel

    private var insights: NetworkLoggerInsights { viewModel.insights }

    public var body: some View {
        List {
            Section(header: Text("Transfer Size")) {
                NetworkInspectorTransferInfoView(viewModel: .init(transferSize: insights.transferSize))
                    .padding(.vertical, 8)
            }
            durationSection
            Section(header: HStack {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundColor(.orange)
                Text("Redirects")
            }) {
                HStack {
                    Image(systemName: "arrowshape.zigzag.right")
                    Text("Redirect Count")
                    Spacer()
                    Text("2")
                }
                HStack {
                    Image(systemName: "clock")
                    Text("Total Time Lost")
                    Spacer()
                    Text("2.6s")
                }
                NavigationLink(destination: Text("Request")) {
                    ConsoleNetworkRequestView(viewModel: .init(request: LoggerStore.preview.entity(for: .createAPI), store: .preview))
                }
                NavigationLink(destination: Text("ViewAll")) {
                    Text("View All")
                }
            }
        }
        .listStyle(.automatic)
        .backport.navigationTitle("Insights")
    }

    private var durationSection: some View {
        Section(header: Text("Duration")) {
            HStack {
                Image(systemName: "clock")
                Text("Median Duration")
                Spacer()
                Text(viewModel.medianDuration)
            }
            HStack {
                Image(systemName: "chart.bar").frame(width: 19)
                Text("Durations Range")
                Spacer()
                Text(viewModel.durationRange)
            }
            durationChart
            NavigationLink(destination: Text("Not implemented")) {
                Text("Show Slowest Requests")
            }
        }
    }

    @ViewBuilder
    private var durationChart: some View {
#if swift(>=5.7)
        if #available(iOS 16.0, *) {
            Chart(viewModel.durationBars) {
                BarMark(
                    x: .value("Duration", $0.range),
                    y: .value("Count", $0.count)
                ).foregroundStyle(barMarkColor(for: $0.range.lowerBound))
            }
            .chartXScale(domain: .automatic(includesZero: false))
            .chartXAxis {
                AxisMarks(values: .automatic(desiredCount: 8)) { value in
                    AxisValueLabel() {
                        if let value = value.as(TimeInterval.self) {
                            Text(DurationFormatter.string(from: TimeInterval(value), isPrecise: false))
                        }
                    }
                }
            }
            .padding(.vertical, 8)
            .frame(height: 140)
        }
#endif
    }

    private func barMarkColor(for duration: TimeInterval) -> Color {
        if duration < 1.0 {
            return Color.green
        } else if duration < 1.9 {
            return Color.yellow
        } else {
            return Color.red
        }
    }
}

final class NetworkInsightsViewModel: ObservableObject {
    let insights: NetworkLoggerInsights
    private var cancellables: [AnyCancellable] = []

    var medianDuration: String {
        guard let median = insights.duration.median else { return "–" }
        return DurationFormatter.string(from: median, isPrecise: false)
    }

    var durationRange: String {
        guard let min = insights.duration.minimum,
              let max = insights.duration.maximum else {
            return "–"
        }
        if min == max {
            return DurationFormatter.string(from: min, isPrecise: false)
        }
        return "\(DurationFormatter.string(from: min, isPrecise: false)) – \(DurationFormatter.string(from: max, isPrecise: false))"
    }

    @available(iOS 16.0, *)
    struct Bar: Identifiable {
        var id: Int { index }

        let index: Int
        let range: ChartBinRange<TimeInterval>
        var count: Int
    }

    @available(iOS 16.0, *)
    var durationBars: [Bar] {
        let values = insights.duration.values.map { min(3.4, $0) }
        let bins = NumberBins(data: values, desiredCount: 30)
        let groups = Dictionary(grouping: values, by: bins.index)
        return groups.map { key, values in
            Bar(index: key, range: bins[key], count: values.count)
        }
    }

    init(store: LoggerStore) {
        self.insights = store.insights
        store.insights.didUpdate.sink { [weak self] in
            self?.objectWillChange.send()
        }.store(in: &cancellables)
    }
}

struct NetworkInsightsView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationView {
            NetworkInsightsView(viewModel: .init(store: LoggerStore.mock))
        }
    }
}

#endif
