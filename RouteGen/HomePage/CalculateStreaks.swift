//
//  CalculateStreaks.swift
//  RouteGen
//
//  Created by 10167 on 31/7/2025.
//

import Foundation

final class CalculateStreaks {
    static let shared = CalculateStreaks()
    private init() {}

    
    
    func computeStreak(completion: @escaping (Result<Int, Error>) -> Void) {
        RunDataManager.shared.fetchRuns { result in
            switch result {
            case .failure(let error):
                print("computeStreak - fetchRuns error: \(error.localizedDescription)")
                completion(.failure(error))

            case .success(let runs):
                print("computeStreak - fetched runs count: \(runs.count)")
                let calendar = Calendar.current
                let runDays: Set<Date> = Set(runs.map { run in
                    let days = calendar.startOfDay(for: run.startTime)
                    print("omputeStreak - run on: \(days)")
                    return days
                })
                print("computeStreak - unique runDays: \(runDays)")

                let today = calendar.startOfDay(for: Date())
                print("computeStreak - today: \(today)")
                let yesterday = calendar.date(byAdding: .day, value: -1, to: today)
                print("computeStreak - yesterday: \(String(describing: yesterday))")

                var streakStartDay: Date
                if runDays.contains(today) {
                    print("computeStreak - streak starts today")
                    streakStartDay = today
                } else if let y = yesterday, runDays.contains(y) {
                    print("computeStreak - streak starts yesterday")
                    streakStartDay = y
                } else {
                    print("computeStreak - no runs today or yesterday, streak = 0")
                    completion(.success(0))
                    return
                }
                
                var streakCount = 0
                var currentDay = streakStartDay
                while runDays.contains(currentDay) {
                    streakCount += 1
                    print("🐛 computeStreak - counting day: \(currentDay), streakCount: \(streakCount)")
                    guard let previousDay = calendar.date(byAdding: .day, value: -1, to: currentDay) else { break }
                    currentDay = previousDay
                }

                print("🐛 computeStreak - final streakCount: \(streakCount)")
                completion(.success(streakCount))
            }
        }
    }
}
