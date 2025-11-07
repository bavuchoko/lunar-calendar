//
//  LunarCalApp.swift
//  LunarCal
//
//  Created by 박종수 on 11/5/25.
//

import SwiftUI

@main
struct LunarCalApp: App {
    let persistenceController = PersistenceController.shared

        var body: some Scene {
            WindowGroup {
                ContentView()
                    .environment(\.managedObjectContext, persistenceController.container.viewContext)
            }
        }
}
