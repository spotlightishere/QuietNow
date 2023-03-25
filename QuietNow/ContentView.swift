//
//  ContentView.swift
//  QuietNow
//
//  Created by Spotlight Deveaux on 2023-03-23.
//

import AVKit
import SwiftUI

struct ContentView: View {
    @State var audioPlayer: AVPlayer = .init()

    var body: some View {
        VStack {
            Text("Hello, world!")
                .onAppear {
                    Task {
                        do {
                            let audioItem = try await createExampleItem()
                            audioPlayer.replaceCurrentItem(with: audioItem)
                            audioPlayer.play()
                        } catch let e {
                            print(e)
                        }
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
