import SwiftUI

struct TodayFilterPanel:View {
    @Binding var status:String
    @Binding var time:String
    @Binding var group:String
    var groups:[String]
    var close:()->Void
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    var body:some View {
        ZStack(alignment:.top) {
            Button(action:close) { Color.black.opacity(0.18).ignoresSafeArea() }.buttonStyle(.plain).keyboardShortcut(.escape,modifiers:[]).accessibilityLabel("Cerrar filtros")
            VStack(alignment:.leading,spacing:17) {
                HStack(alignment:.top,spacing:10) {
                    Text("Estado").font(.system(size:13)).frame(width:54,alignment:.leading).padding(.top,3)
                    HStack(spacing:0) { ForEach(HabitStatusFilter.allCases,id:\.self) { item in
                        Button { status = item.rawValue } label:{ Text(item.title).font(.system(size:12)).lineLimit(1).minimumScaleFactor(0.8).padding(.horizontal,10).frame(height:23).background(status == item.rawValue ? Color.repeatPink : .clear,in:Capsule()).foregroundStyle(status == item.rawValue ? Color.white : Color.secondary) }
                            .buttonStyle(.plain).accessibilityLabel("Estado: \(item.title)").accessibilityAddTraits(status == item.rawValue ? .isSelected : [])
                    } }.background(Color(.secondarySystemGroupedBackground),in:Capsule())
                    Spacer(minLength:0)
                }
                HStack(alignment:.top,spacing:10) {
                    Text("Horario").font(.system(size:13)).frame(width:54,alignment:.leading).padding(.top,3)
                    FilterFlowLayout(spacing:6) { ForEach(HabitTimeFilter.allCases,id:\.self) { item in
                        chip(item.title,selected:time == item.rawValue,label:"Horario: \(item.title)") { time = item.rawValue; close() }
                    } }
                }
                if !groups.isEmpty {
                    HStack(alignment:.top,spacing:10) {
                        Text("Grupo").font(.system(size:13)).frame(width:54,alignment:.leading).padding(.top,3)
                        ScrollView(.horizontal,showsIndicators:false) { HStack(spacing:6) { chip("Todos",selected:group.isEmpty,label:"Grupo: Todos") { group = ""; close() }; ForEach(groups,id:\.self) { name in chip(name,selected:group == name,label:"Grupo: \(name)") { group = name; close() } } } }
                    }
                }
            }.padding(.horizontal,16).padding(.top,12).padding(.bottom,16)
                .frame(maxWidth:.infinity,alignment:.leading)
                .background { UnevenRoundedRectangle(bottomLeadingRadius:23,bottomTrailingRadius:23).fill(Color(.systemGroupedBackground)).ignoresSafeArea(edges:.top) }
                .accessibilityAddTraits(.isModal)
                .transition(reduceMotion ? .opacity : .move(edge:.top).combined(with:.opacity))
        }
    }
    func chip(_ title:String,selected:Bool,label:String,action:@escaping()->Void) -> some View {
        Button(action:action) { Text(title).font(.system(size:12)).lineLimit(1).padding(.horizontal,11).frame(height:23).background(selected ? Color.repeatPink : Color(.secondarySystemGroupedBackground),in:Capsule()).foregroundStyle(selected ? Color.white : Color.secondary) }.buttonStyle(.plain).accessibilityLabel(label).accessibilityAddTraits(selected ? .isSelected : [])
    }
}

struct FilterFlowLayout:Layout {
    var spacing:CGFloat = 6
    func positions(_ proposal:ProposedViewSize,_ subviews:Subviews) -> (CGSize,[CGPoint]) {
        let width = proposal.width ?? .greatestFiniteMagnitude
        var x:CGFloat = 0,y:CGFloat = 0,rowHeight:CGFloat = 0,usedWidth:CGFloat = 0
        var points:[CGPoint] = []
        for view in subviews {
            let size = view.sizeThatFits(.unspecified)
            if x > 0 && x+size.width > width { x = 0; y += rowHeight+spacing; rowHeight = 0 }
            points.append(CGPoint(x:x,y:y)); usedWidth = max(usedWidth,x+size.width); x += size.width+spacing; rowHeight = max(rowHeight,size.height)
        }
        return (CGSize(width:proposal.width ?? usedWidth,height:y+rowHeight),points)
    }
    func sizeThatFits(proposal:ProposedViewSize,subviews:Subviews,cache:inout ()) -> CGSize { positions(proposal,subviews).0 }
    func placeSubviews(in bounds:CGRect,proposal:ProposedViewSize,subviews:Subviews,cache:inout ()) {
        let points = positions(ProposedViewSize(width:bounds.width,height:bounds.height),subviews).1
        for (index,view) in subviews.enumerated() { view.place(at:CGPoint(x:bounds.minX+points[index].x,y:bounds.minY+points[index].y),anchor:.topLeading,proposal:.unspecified) }
    }
}
