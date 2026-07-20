import WidgetKit
import SwiftUI

@main
struct RunUpWidgetsBundle: WidgetBundle {
    var body: some Widget {
        DailyGoalsWidget()
        RunActivityWidget()
    }
}
