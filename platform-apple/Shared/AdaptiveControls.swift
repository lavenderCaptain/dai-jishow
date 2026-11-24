// AdaptiveControls.swift — "crunch down to the icon when cramped" helpers.
//
// When the window is narrow, a row of icon+label controls can start to spill a
// label onto a second line (the "Graph Mode → 4-line mess" symptom, and the
// Word Cloud "Roll" button doing the same). These helpers let a row measure the
// width it is *actually* given and, below a per-row threshold, render its
// icon+label controls **icon-only** (the text is dropped, not truncated) so
// nothing ever wraps.
//
// A tooltip is ALWAYS attached to each control, so a collapsed icon-only control
// stays self-documenting — this is what makes "just the dots, no words" usable
// for the colour legends at small sizes.
//
// Design note: the decision is made from a *single measured row width* against a
// named threshold (not a per-control magic number), so the behaviour is easy to
// reason about and tune. In compact mode the controls contain no `Text`, so a
// two-line spill is structurally impossible regardless of where the threshold
// lands.

import SwiftUI

// MARK: - Row-width measurement

extension View {
    /// Publish this view's laid-out width (in points) to `width` via a zero-effect
    /// `GeometryReader` background. Non-invasive: the reader adds no size, so it
    /// never changes the layout it is measuring.
    ///
    /// Attach it to a control row, feed a `@State` width, and gate the row's
    /// icon+label controls on a `compact` flag derived from that width.
    func measureWidth(into width: Binding<CGFloat>) -> some View {
        background(
            GeometryReader { proxy in
                Color.clear
                    .onAppear { width.wrappedValue = proxy.size.width }
                    .onChange(of: proxy.size.width) { _, new in
                        width.wrappedValue = new
                    }
            }
        )
    }
}

/// Free-function form of the compact gate: `0` width is the "not measured yet"
/// sentinel, treated as *not compact*, so the first render shows the full layout.
func isRowCompact(_ width: CGFloat, threshold: CGFloat) -> Bool {
    width > 0 && width < threshold
}
