import SwiftUI
import WidgetKit

@main
struct FocusTimeWidgetBundle: WidgetBundle {
    var body: some Widget {
        TodayProgressWidget()
        FocusLiveActivity()
    }
}
