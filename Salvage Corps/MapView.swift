//
//  MapView.swift
//  Salvage Corps
//
//  Visualização do mapa do ato atual. Slay-the-Spire style:
//  colunas horizontais, player navega da esquerda pra direita.
//
//  Versão inicial funcional — polish visual (parallax, animações de path,
//  fog of war) vem em iteração futura.
//

import SwiftUI
import SalvageCore

struct MapView: View {

    @Bindable var mapStore: MapStore

    /// Callback quando o player toca em um nó disponível.
    var onNodeSelected: (MapNode) -> Void

    // MARK: - Constants

    private var nodeSize: CGFloat { 52.s }
    private var columnSpacing: CGFloat { 90.s }
    private var rowSpacing: CGFloat { 70.s }
    private var mapPadding: CGFloat { 40.s }

    var body: some View {
        if let map = mapStore.currentMap {
            ScrollView(.horizontal, showsIndicators: false) {
                ZStack {
                    // Fundo temático
                    Image("bg_no_mans_land")
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .overlay(Color.black.opacity(0.7))

                    // Grid do mapa: edges primeiro (atrás), nós por cima
                    ZStack {
                        edgesLayer(map: map)
                        nodesLayer(map: map)
                    }
                    .padding(mapPadding)
                }
            }
            .background(Color.black)
            .overlay(alignment: .top) {
                actHeader
            }
        } else {
            emptyState
        }
    }

    // MARK: - Header

    private var actHeader: some View {
        VStack(spacing: 2.s) {
            Text("map.act \(mapStore.currentAct)")
                .font(SalvageFont.label(11))
                .tracking(4.s)
                .foregroundStyle(SalvageColor.energyOrange)
            Text(actTitle)
                .font(SalvageFont.title(16))
                .foregroundStyle(SalvageColor.boneWhite)
        }
        .padding(.horizontal, 16.s)
        .padding(.vertical, 8.s)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 6.s))
        .padding(.top, 12.s)
    }

    private var actTitle: String {
        NSLocalizedString("act.\(mapStore.currentAct).name", bundle: .main, comment: "Act title on map")
    }

    // MARK: - Empty state

    private var emptyState: some View {
        VStack(spacing: 12.s) {
            Text("map.no_run_title")
                .font(SalvageFont.body(14))
                .foregroundStyle(SalvageColor.boneWhite.opacity(0.6))
            Text("map.no_run_subtitle")
                .font(SalvageFont.flavor(12))
                .italic()
                .foregroundStyle(.white.opacity(0.4))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.black)
    }

    // MARK: - Nodes layer

    private func nodesLayer(map: GameMap) -> some View {
        ZStack {
            ForEach(map.nodes) { node in
                nodeView(node)
                    .position(position(for: node, in: map))
            }
        }
        .frame(
            width: CGFloat(map.columnCount) * columnSpacing,
            height: CGFloat(4) * rowSpacing
        )
    }

    private func nodeView(_ node: MapNode) -> some View {
        let isVisited = mapStore.isVisited(node.id)
        let isCurrent = mapStore.isCurrent(node.id)
        let isAvailable = mapStore.isAvailable(node.id)

        return Button {
            guard isAvailable else { return }
            onNodeSelected(node)
        } label: {
            ZStack {
                Circle()
                    .fill(fillColor(for: node, isVisited: isVisited, isCurrent: isCurrent))
                    .frame(width: nodeSize, height: nodeSize)
                    .overlay(
                        Circle()
                            .stroke(strokeColor(isAvailable: isAvailable, isCurrent: isCurrent), lineWidth: strokeWidth(isAvailable: isAvailable, isCurrent: isCurrent))
                    )

                Image(systemName: iconName(for: node.kind))
                    .font(.system(size: 20.s))
                    .foregroundStyle(iconColor(isVisited: isVisited))
            }
            .opacity(isVisited && !isCurrent ? 0.45 : 1.0)
        }
        .buttonStyle(.plain)
        .disabled(!isAvailable)
    }

    // MARK: - Edges layer

    private func edgesLayer(map: GameMap) -> some View {
        Canvas { context, size in
            for edge in map.edges {
                guard let from = map.node(id: edge.from),
                      let to = map.node(id: edge.to) else { continue }

                let fromPos = position(for: from, in: map)
                let toPos = position(for: to, in: map)

                var path = Path()
                path.move(to: fromPos)
                path.addLine(to: toPos)

                // Edge visitada = laranja sólido; disponível = laranja tênue; futura = cinza fraco
                let isVisited = mapStore.isVisited(from.id) && mapStore.isVisited(to.id)
                let isActive = mapStore.isCurrent(from.id) || mapStore.isVisited(from.id)

                let strokeColor: Color
                if isVisited {
                    strokeColor = Color(red: 0.95, green: 0.55, blue: 0.15).opacity(0.9)
                } else if isActive {
                    strokeColor = Color(red: 0.95, green: 0.55, blue: 0.15).opacity(0.5)
                } else {
                    strokeColor = Color.white.opacity(0.15)
                }

                context.stroke(
                    path,
                    with: .color(strokeColor),
                    style: StrokeStyle(lineWidth: 2.s, dash: isVisited ? [] : [4, 4])
                )
            }
        }
        .frame(
            width: CGFloat(map.columnCount) * columnSpacing,
            height: CGFloat(4) * rowSpacing
        )
    }

    // MARK: - Layout helpers

    private func position(for node: MapNode, in map: GameMap) -> CGPoint {
        let x = CGFloat(node.position.column) * columnSpacing + columnSpacing / 2
        let y = CGFloat(node.position.row) * rowSpacing + rowSpacing / 2
        return CGPoint(x: x, y: y)
    }

    // MARK: - Style helpers

    private func iconName(for kind: NodeKind) -> String {
        switch kind {
        case .combat:   return "flame.fill"
        case .elite:    return "flame.circle.fill"
        case .boss:     return "crown.fill"
        case .camp:     return "tent.fill"
        case .event:    return "questionmark.diamond.fill"
        case .merchant: return "bag.fill"
        }
    }

    private func fillColor(for node: MapNode, isVisited: Bool, isCurrent: Bool) -> Color {
        if isCurrent { return Color(red: 0.95, green: 0.55, blue: 0.15) }
        if isVisited { return Color.black.opacity(0.6) }
        // Cor base por tipo
        switch node.kind {
        case .combat:   return Color(red: 0.35, green: 0.15, blue: 0.15)
        case .elite:    return Color(red: 0.55, green: 0.15, blue: 0.15)
        case .boss:     return Color(red: 0.15, green: 0.05, blue: 0.05)
        case .camp:     return Color(red: 0.25, green: 0.35, blue: 0.15)
        case .event:    return Color(red: 0.25, green: 0.25, blue: 0.35)
        case .merchant: return Color(red: 0.35, green: 0.30, blue: 0.15)
        }
    }

    private func strokeColor(isAvailable: Bool, isCurrent: Bool) -> Color {
        if isCurrent { return Color(red: 0.92, green: 0.88, blue: 0.78) }
        if isAvailable { return Color(red: 0.95, green: 0.55, blue: 0.15) }
        return Color.white.opacity(0.25)
    }

    private func strokeWidth(isAvailable: Bool, isCurrent: Bool) -> CGFloat {
        if isCurrent { return 3 }
        if isAvailable { return 2 }
        return 1
    }

    private func iconColor(isVisited: Bool) -> Color {
        isVisited
            ? Color(red: 0.92, green: 0.88, blue: 0.78).opacity(0.55)
            : Color(red: 0.92, green: 0.88, blue: 0.78)
    }
}
