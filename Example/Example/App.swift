import ComposableArchitecture
import ComposablePresentation
import SwiftUI

@main
struct App: SwiftUI.App {
  var body: some Scene {
    WindowGroup {
      AppView(store: Store(
        initialState: AppState(),
        reducer: appReducer.debug(),
        environment: ()
      ))
    }
  }
}

// MARK: - App component

struct AppState {
  var first = FirstState()
}

enum AppAction {
  case dismissSecond
  case dismissThird
  case dismissFourth
  case first(FirstAction)
}

let appReducer = Reducer<AppState, AppAction, Void>.combine(
  firstReducer.pullback(
    state: \.first,
    action: /AppAction.first,
    environment: { () }
  )
)

struct AppView: View {
  let store: Store<AppState, AppAction>

  var body: some View {
    NavigationView {
      FirstView(store: store.scope(
        state: \.first,
        action: AppAction.first
      ))
    }
    .navigationViewStyle(StackNavigationViewStyle())
  }
}

#if DEBUG
struct AppView_Previews: PreviewProvider {
  static var previews: some View {
    AppView(store: Store(
      initialState: AppState(),
      reducer: appReducer,
      environment: ()
    ))
  }
}
#endif

// MARK: - Timer component

struct TimerState: Identifiable {
  struct ID: Hashable {
    var uuid = UUID()
  }

  let id = ID()
  var seconds: Int = 0
}

enum TimerAction {
  case start
  case tick
}

let timerReducer = Reducer<TimerState, TimerAction, Void> { state, action, _ in
  switch action {
  case .start:
    return Effect.timer(id: state.id, every: 1, on: DispatchQueue.main)
      .map { _ in TimerAction.tick }

  case .tick:
    state.seconds += 1
    return .none
  }
}

struct TimerView: View {
  let store: Store<TimerState, TimerAction>

  var body: some View {
    WithViewStore(store.scope(state: \.seconds)) { viewStore in
      Text("\(viewStore.state)")
        .padding()
        .foregroundColor(.gray)
        .background(Color.white)
        .onAppear { viewStore.send(.start) }
    }
  }
}

// MARK: - First component

struct FirstState {
  var timer = TimerState()
  var second: SecondState?
  var sheet: SheetState?
}

enum FirstAction {
  case didTapPresentSecond
  case didDismissSecond
  case didTapPresentSheet
  case didDismissSheet
  case timer(TimerAction)
  case second(SecondAction)
  case sheet(SheetAction)
}

let firstReducer = Reducer<FirstState, FirstAction, Void>.combine(
  timerReducer.pullback(
    state: \.timer,
    action: /FirstAction.timer,
    environment: { () }
  ),

  Reducer { state, action, _ in
    switch action {
    case .didTapPresentSecond:
      state.second = SecondState()
      return .none

    case .didDismissSecond,
         .second(.didTapDismissSecond),
         .second(.third(.didTapDismissSecond)),
         .second(.fourth(.didTapDismissSecond)):
      state.second = nil
      return .none

    case .didTapPresentSheet:
      state.sheet = SheetState()
      return .none

    case .didDismissSheet,
         .sheet(.didTapDismiss):
      state.sheet = nil
      return .none

    case .timer(_):
      return .none

    case .second(_):
      return .none

    case .sheet(_):
      return .none
    }
  }
)
.presents(
  secondReducer,
  state: \.second,
  action: /FirstAction.second,
  environment: { () }
)
.presents(
  sheetReducer,
  state: \.sheet,
  action: /FirstAction.sheet,
  environment: { () }
)

struct FirstView: View {
  let store: Store<FirstState, FirstAction>

  var body: some View {
    WithViewStore(store.stateless) { viewStore in
      VStack {
        TimerView(store: store.scope(
          state: \.timer,
          action: FirstAction.timer
        ))
        .padding()

        Button(action: { viewStore.send(.didTapPresentSecond) }) {
          Text("Present Second").padding()
        }

        Button(action: { viewStore.send(.didTapPresentSheet) }) {
          Text("Present Sheet").padding()
        }
      }
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background(Color.orange.ignoresSafeArea())
    .navigationTitle("First")
    .navigationLink(
      store.scope(state: \.second, action: FirstAction.second),
      state: replayNonNil(),
      onDismiss: { ViewStore(store.stateless).send(.didDismissSecond) },
      destination: SecondView.init(store:)
    )
    .sheet(
      store.scope(state: \.sheet, action: FirstAction.sheet),
      state: replayNonNil(),
      onDismiss: { ViewStore(store.stateless).send(.didDismissSheet) },
      destination: SheetView.init(store:)
    )
  }
}

// MARK: - Second component

struct SecondState {
  enum Next {
    case third(ThirdState)
    case fourth(FourthState)
  }

  var timer = TimerState()
  var next: Next?
}

enum SecondAction {
  case didTapDismissSecond
  case didTapPresentThird
  case didTapPresentFourth
  case didDismissThird
  case didDismissFourth
  case timer(TimerAction)
  case third(ThirdAction)
  case fourth(FourthAction)
}

let secondReducer = Reducer<SecondState, SecondAction, Void>.combine(
  timerReducer.pullback(
    state: \.timer,
    action: /SecondAction.timer,
    environment: { () }
  ),

  Reducer { state, action, _ in
    switch action {
    case .didTapDismissSecond:
      return .none

    case .didTapPresentThird:
      state.next = .third(ThirdState())
      return .none

    case .didDismissThird,
         .third(.didTapDismissThird):
      state.next = nil
      return .none

    case .didTapPresentFourth:
      state.next = .fourth(FourthState())
      return .none

    case .didDismissFourth,
         .fourth(.didTapDismissFourth):
      state.next = nil
      return .none

    case .timer(_):
      return .none

    case .third(_):
      return .none

    case .fourth(_):
      return .none
    }
  }
)
.presents(
  thirdReducer.pullback(
    state: /SecondState.Next.third,
    action: /.self,
    environment: { $0 }
  ),
  state: \.next,
  action: /SecondAction.third,
  environment: { () }
)
.presents(
  fourthReducer.pullback(
    state: /SecondState.Next.fourth,
    action: /.self,
    environment: { $0 }
  ),
  state: \.next,
  action: /SecondAction.fourth,
  environment: { () }
)

struct SecondView: View {
  let store: Store<SecondState, SecondAction>

  var body: some View {
    WithViewStore(store.stateless) { viewStore in
      VStack {
        TimerView(store: store.scope(
          state: \.timer,
          action: SecondAction.timer
        ))
        .padding()

        Button(action: { viewStore.send(.didTapDismissSecond) }) {
          Text("Dismiss Second").padding()
        }

        Button(action: { viewStore.send(.didTapPresentThird) }) {
          Text("Present Third").padding()
        }

        Button(action: { viewStore.send(.didTapPresentFourth) }) {
          Text("Present Fourth").padding()
        }
      }
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background(Color.green.ignoresSafeArea())
    .navigationTitle("Second")
    .navigationLink(
      store.scope(state: \.next).scope(
        state: (/SecondState.Next.third).extract,
        action: SecondAction.third
      ),
      state: replayNonNil(),
      onDismiss: { ViewStore(store.stateless).send(.didDismissThird) },
      destination: ThirdView.init(store:)
    )
    .navigationLink(
      store.scope(state: \.next).scope(
        state: (/SecondState.Next.fourth).extract,
        action: SecondAction.fourth
      ),
      state: replayNonNil(),
      onDismiss: { ViewStore(store.stateless).send(.didDismissFourth) },
      destination: FourthView.init(store:)
    )
  }
}

// MARK: - Third component

struct ThirdState {
  var timer = TimerState()
}

enum ThirdAction {
  case didTapDismissSecond
  case didTapDismissThird
  case timer(TimerAction)
}

let thirdReducer = Reducer<ThirdState, ThirdAction, Void>.combine(
  timerReducer.pullback(
    state: \.timer,
    action: /ThirdAction.timer,
    environment: { () }
  ),

  Reducer { state, action, _ in
    switch action {
    case .didTapDismissSecond:
      return .none

    case .didTapDismissThird:
      return .none

    case .timer(_):
      return .none
    }
  }
)

struct ThirdView: View {
  let store: Store<ThirdState, ThirdAction>

  var body: some View {
    WithViewStore(store.stateless) { viewStore in
      VStack {
        TimerView(store: store.scope(
          state: \.timer,
          action: ThirdAction.timer
        ))
        .padding()

        Button(action: { viewStore.send(.didTapDismissSecond) }) {
          Text("Dismiss Second").padding()
        }

        Button(action: { viewStore.send(.didTapDismissThird) }) {
          Text("Dismiss Third").padding()
        }
      }
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background(Color.gray.ignoresSafeArea())
    .navigationTitle("Third")
  }
}

// MARK: - Fourth component

struct FourthState {
  var timer = TimerState()
}

enum FourthAction {
  case didTapDismissSecond
  case didTapDismissFourth
  case timer(TimerAction)
}

let fourthReducer = Reducer<FourthState, FourthAction, Void>.combine(
  timerReducer.pullback(
    state: \.timer,
    action: /FourthAction.timer,
    environment: { () }
  ),

  Reducer { state, action, _ in
    switch action {
    case .didTapDismissSecond:
      return .none

    case .didTapDismissFourth:
      return .none

    case .timer(_):
      return .none
    }
  }
)

struct FourthView: View {
  let store: Store<FourthState, FourthAction>

  var body: some View {
    WithViewStore(store.stateless) { viewStore in
      VStack {
        TimerView(store: store.scope(
          state: \.timer,
          action: FourthAction.timer
        ))
        .padding()

        Button(action: { viewStore.send(.didTapDismissSecond) }) {
          Text("Dismiss Second").padding()
        }

        Button(action: { viewStore.send(.didTapDismissFourth) }) {
          Text("Dismiss Fourth").padding()
        }
      }
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background(Color.purple.ignoresSafeArea())
    .navigationTitle("Fourth")
  }
}

// MARK: - Sheet component

struct SheetState {
  var timer = TimerState()
}

enum SheetAction {
  case didTapDismiss
  case timer(TimerAction)
}

let sheetReducer = Reducer<SheetState, SheetAction, Void>.combine(
  timerReducer.pullback(
    state: \.timer,
    action: /SheetAction.timer,
    environment: { () }
  ),

  Reducer { state, action, _ in
    switch action {
    case .didTapDismiss:
      return .none

    case .timer(_):
      return .none
    }
  }
)

struct SheetView: View {
  let store: Store<SheetState, SheetAction>

  var body: some View {
    WithViewStore(store.stateless) { viewStore in
      VStack {
        TimerView(store: store.scope(
          state: \.timer,
          action: SheetAction.timer
        ))
        .padding()

        Button(action: { viewStore.send(.didTapDismiss) }) {
          Text("Dismiss").padding()
        }
      }
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background(Color.green.ignoresSafeArea())
  }
}
