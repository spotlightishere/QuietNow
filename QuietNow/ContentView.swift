//
//  ContentView.swift
//  QuietNow
//
//  Created by Spotlight Deveaux on 2023-03-23.
//

import SwiftUI

struct ContentView: View {
    var body: some View {
        VStack {
            Text("Hello, world!")
                .onAppear {
                    do {
                        try playExample()
                    } catch let e {
                        print(e)
                    }
                }
        }
        .padding()
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
