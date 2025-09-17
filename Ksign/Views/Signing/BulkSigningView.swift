//
//  BulkSigningView.swift
//  Ksign
//
//  Created by Nagata Asami on 11/9/25.
//

import SwiftUI
import NimbleViews

struct BulkSigningView: View {
	@Environment(\.dismiss) private var dismiss

	var body: some View {
		NBNavigationView(.localized("Bulk Signing")) {
			Text("Bulk Signing")
		}
		.toolbar {
			NBToolbarButton(role: .dismiss)
		}
	}
}
