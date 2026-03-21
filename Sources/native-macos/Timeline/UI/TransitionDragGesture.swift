import SwiftUI

struct TransitionDragGesture: ViewModifier {
    let transition: TransitionClip
    let viewModel: TimelineViewModel
    let edge: TimelineViewModel.TransitionEdge

    func body(content: Content) -> some View {
        content
            .gesture(
                DragGesture(coordinateSpace: .global)
                    .onChanged { value in
                        viewModel.handleTransitionDrag(
                            transitionID: transition.id,
                            edge: edge,
                            offset: value.translation.width
                        )
                    }
                    .onEnded { _ in
                        viewModel.endTransitionDrag()
                    }
            )
    }
}

extension View {
    /// Applies transition drag gesture to a view
    func transitionDragGesture(
        transition: TransitionClip,
        viewModel: TimelineViewModel,
        edge: TimelineViewModel.TransitionEdge
    ) -> some View {
        self.modifier(TransitionDragGesture(transition: transition, viewModel: viewModel, edge: edge))
    }
}
