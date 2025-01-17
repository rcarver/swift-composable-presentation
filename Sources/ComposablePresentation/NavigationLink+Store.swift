import ComposableArchitecture
import SwiftUI

extension NavigationLink {
  /// Creates `NavigationLink` using a `Store` with an optional `State`.
  ///
  /// The link is active if `State` is non-`nil` and inactive when it's `nil`.
  ///
  /// - Parameters:
  ///   - store: Store with an optional state.
  ///   - state: Optional closure that takes `State?` and returns `State?` used to create destination view. Default value returns unchnaged state.
  ///   - setActive: Closure invoked when link is activated and deactivated.
  ///   - destination: Closure that creates destination view with a store with non-optional state.
  ///   - label: View used as a link's label.
  /// - Returns: `NavigationLink` wrapped in a `WithViewStore`.
  public static func store<State, Action, DestinationContent>(
    _ store: Store<State?, Action>,
    state: @escaping (State?) -> State? = { $0 },
    setActive: @escaping (Bool) -> Void,
    destination: @escaping (Store<State, Action>) -> DestinationContent,
    label: @escaping () -> Label
  ) -> some View
  where DestinationContent: View,
        Destination == IfLetStore<State, Action, DestinationContent?>
  {
    WithViewStore(store.scope(state: { $0 != nil })) { viewStore in
      NavigationLink(
        destination: IfLetStore(
          store.scope(state: state),
          then: destination
        ),
        isActive: Binding(
          get: { viewStore.state },
          set: setActive
        ),
        label: label
      )
    }
  }
}

extension View {
  /// Adds `NavigationLink` without a label, using `Store` with an optional `State`.
  ///
  /// The link is active if `State?` is non-`nil` and inactive when it's `nil`.
  ///
  /// - Parameters:
  ///   - store: Store with an optional state.
  ///   - state: Optional closure that takes `State?` and returns `State?` used to create destination view. Default value returns unchnaged state.
  ///   - onDismiss: Closure invoked when link is deactivated.
  ///   - destination: Closure that creates destination view with a store with non-optional state.
  /// - Returns: View with label-less `NavigationLink` added in a background view.
  public func navigationLink<State, Action, Destination: View>(
    _ store: Store<State?, Action>,
    state: @escaping (State?) -> State? = { $0 },
    onDismiss: @escaping () -> Void,
    destination: @escaping (Store<State, Action>) -> Destination
  ) -> some View {
    background(
      NavigationLink.store(
        store,
        state: state,
        setActive: { active in
          if active == false {
            onDismiss()
          }
        },
        destination: destination,
        label: EmptyView.init
      )
    )
  }
}
