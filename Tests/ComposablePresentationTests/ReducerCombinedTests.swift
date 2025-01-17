import Combine
import ComposableArchitecture
import XCTest
@testable import ComposablePresentation

final class ReducerCombinedTests: XCTestCase {
  var reducer: Reducer<[String], String, Void>!
  var shouldCancelChildEffect: Bool!
  var mainEffectSubject: PassthroughSubject<String, Never>!
  var childEffectSubject: PassthroughSubject<String, Never>!
  var didCallCancelEffectsOnState: [[String]]!
  var didCancelMainEffect: Bool!
  var didCancelChildEffect: Bool!

  override func setUp() {
    mainEffectSubject = PassthroughSubject()
    childEffectSubject = PassthroughSubject()
    didCallCancelEffectsOnState = []
    didCancelMainEffect = false
    didCancelChildEffect = false

    reducer = Reducer { state, action, _ in
      state.append("main-reducer-\(action)")
      return self.mainEffectSubject
        .handleEvents(receiveCancel: { self.didCancelMainEffect = true })
        .map { "main-effect-\($0)" }
        .eraseToEffect()
    }
    .combined(
      with: Reducer { state, action, _ in
        state.append("child-reducer-\(action)")
        return self.childEffectSubject
          .handleEvents(receiveCancel: { self.didCancelChildEffect = true })
          .map { "child-effect-\($0)" }
          .eraseToEffect()
      },
      cancelEffects: { state in
        self.didCallCancelEffectsOnState.append(state)
        return self.shouldCancelChildEffect
      }
    )
  }

  override func tearDown() {
    reducer = nil
    shouldCancelChildEffect = nil
    mainEffectSubject = nil
    childEffectSubject = nil
    didCallCancelEffectsOnState = nil
    didCancelMainEffect = nil
    didCancelChildEffect = nil
  }

  func testCancelChildEffects() {
    let store = TestStore(
      initialState: [],
      reducer: reducer,
      environment: ()
    )

    shouldCancelChildEffect = true

    store.send("1") {
      $0.append(contentsOf: ["child-reducer-1", "main-reducer-1"])
    }

    XCTAssertEqual(didCallCancelEffectsOnState.count, 1)
    XCTAssertEqual(didCallCancelEffectsOnState.last, ["child-reducer-1", "main-reducer-1"])
    XCTAssertFalse(didCancelMainEffect)
    XCTAssertTrue(didCancelChildEffect)

    mainEffectSubject.send("2")

    store.receive("main-effect-2") {
      $0.append(contentsOf: ["child-reducer-main-effect-2", "main-reducer-main-effect-2"])
    }

    childEffectSubject.send("3")

    mainEffectSubject.send(completion: .finished)
  }

  func testNotCancelChildEffects() {
    let store = TestStore(
      initialState: [],
      reducer: reducer,
      environment: ()
    )

    shouldCancelChildEffect = false

    store.send("1") {
      $0.append(contentsOf: ["child-reducer-1", "main-reducer-1"])
    }

    XCTAssertEqual(didCallCancelEffectsOnState.count, 1)
    XCTAssertEqual(didCallCancelEffectsOnState.last, ["child-reducer-1", "main-reducer-1"])
    XCTAssertFalse(didCancelMainEffect)
    XCTAssertFalse(didCancelChildEffect)

    mainEffectSubject.send("2")

    store.receive("main-effect-2") {
      $0.append(contentsOf: ["child-reducer-main-effect-2", "main-reducer-main-effect-2"])
    }

    childEffectSubject.send("3")

    store.receive("child-effect-3") {
      $0.append(contentsOf: ["child-reducer-child-effect-3", "main-reducer-child-effect-3"])
    }

    store.receive("child-effect-3") {
      $0.append(contentsOf: ["child-reducer-child-effect-3", "main-reducer-child-effect-3"])
    }

    mainEffectSubject.send(completion: .finished)
    childEffectSubject.send(completion: .finished)
  }
}
