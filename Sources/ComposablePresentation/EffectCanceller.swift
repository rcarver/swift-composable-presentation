import Foundation
import Combine
import ComposableArchitecture

protocol EffectCancelling {

  func register<P: Publisher>(
    _ publisher: P
  ) -> Effect<P.Output, P.Failure>

  func cancel<NewOutput, NewFailure>(
    outputType: NewOutput.Type,
    failureType: NewFailure.Type
  ) -> Effect<NewOutput, NewFailure>
}

extension Effect {

  func cancellable(with canceller: EffectCancelling) -> Effect {
    canceller.register(self)
  }

  static func cancel<NewOutput, NewFailure>(
    with canceller: EffectCancelling,
    outputType: NewOutput.Type = NewOutput.self,
    failureType: NewFailure.Type = NewFailure.self
  ) -> Effect<NewOutput, NewFailure> {
    canceller.cancel(outputType: outputType, failureType: failureType)
  }
}

/// ID of cancellable effects. The name is for easier debugging.
struct CancellationId: Hashable {
  let id: AnyHashable
  let name: String
}

extension CancellationId: CustomStringConvertible {
  var description: String {
    "CancellationId<\(id):\(name)>"
  }
}

/// Performs cancellation by ID, delegating to the standard TCA implementation.
struct IdentifiedCanceller: EffectCancelling {

  let id: CancellationId

  func register<P: Publisher>(_ publisher: P) -> Effect<P.Output, P.Failure> {
    publisher
      .eraseToEffect()
      .cancellable(id: id)
  }

  func cancel<NewOutput, NewFailure>(
    outputType: NewOutput.Type,
    failureType: NewFailure.Type
  ) -> Effect<NewOutput, NewFailure> {
    .cancel(id: id)
  }
}

/// Performs cancellation within a single scope.
/// It also implements cancellation without thread synchronization.
/// The ID is for debugging only.
final class NonLockingScopedCanceller: EffectCancelling {

  init(id: CancellationId) {
    self.id = id
  }

  private let id: CancellationId
  private var cancellables = Set<AnyCancellable>()

  func register<P: Publisher>(_ publisher: P) -> Effect<P.Output, P.Failure> {
    Deferred { () -> AnyPublisher<P.Output, P.Failure> in

      let downstream = PassthroughSubject<P.Output, P.Failure>()
      let upstream = publisher.subscribe(downstream)
      var cancellable: AnyCancellable!

      cancellable = AnyCancellable {
        downstream.send(completion: .finished)
        upstream.cancel()
        self.cancellables.remove(cancellable)
      }

      self.cancellables.insert(cancellable)

      return downstream.handleEvents(
        receiveCompletion: { _ in cancellable.cancel() },
        receiveCancel: cancellable.cancel
      )
        .eraseToAnyPublisher()
    }
    .eraseToEffect()
  }

  func cancel<NewOutput, NewFailure>(
    outputType: NewOutput.Type,
    failureType: NewFailure.Type
  ) -> Effect<NewOutput, NewFailure> {
    .fireAndForget {
      self.cancellables.forEach { $0.cancel() }
      self.cancellables = .init()
    }
  }
}
