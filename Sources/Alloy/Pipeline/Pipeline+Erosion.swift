//
//  Pipeline+Erosion.swift
//  Alloy
//

import Foundation

public extension Pipeline where State: BlackAndWhite {
    /// Morphological erosion. Offered only where the state is known binary;
    /// the state is preserved, so the result is still erodable and analysable.
    func erosion(
        iterations: Int = 1,
        connectivity: ErosionConnectivity = .eight,
    ) -> Pipeline<State> {
        appending { try $0.erosion(iterations: iterations, connectivity: connectivity) }
    }
}
