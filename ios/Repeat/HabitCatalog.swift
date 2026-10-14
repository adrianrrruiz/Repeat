import SwiftUI

struct HabitTemplate: Identifiable {
    var id:String; var name:String; var icon:String; var color:String; var goal:Double; var unit:String; var category:String; var health:String? = nil; var type = "build"
    func make(order:Int) -> Habit { var h = Habit(); h.name = name; h.icon = icon; h.color = color; h.goal = goal; h.unit = unit; h.order = order; h.type = type; h.memoAfter = true; return h }
    static let all:[HabitTemplate] = [
        .init(id:"walk",name:"Caminar",icon:"🚶",color:"#7895E0",goal:10000,unit:"pasos",category:"Deportes",health:"steps"),
        .init(id:"sleep",name:"Dormir",icon:"🛏️",color:"#8D71E1",goal:7,unit:"hr",category:"Salud",health:"sleep"),
        .init(id:"water",name:"Tomar agua",icon:"💧",color:"#5CBAF0",goal:2000,unit:"ml",category:"Salud",health:"water"),
        .init(id:"meditate",name:"Meditar",icon:"🧘",color:"#3BD6BE",goal:5,unit:"min",category:"Salud",health:"mindful"),
        .init(id:"run",name:"Correr",icon:"🏃",color:"#F4756A",goal:5,unit:"km",category:"Deportes",health:"distance"),
        .init(id:"stand",name:"Ponerse de pie",icon:"🧍",color:"#8FC77D",goal:30,unit:"min",category:"Salud",health:"stand"),
        .init(id:"cycle",name:"Andar en bicicleta",icon:"🚴",color:"#76C8D0",goal:30,unit:"min",category:"Deportes"),
        .init(id:"workout",name:"Hacer ejercicio",icon:"💪",color:"#F4B357",goal:30,unit:"min",category:"Deportes",health:"exercise"),
        .init(id:"energy",name:"Energía activa",icon:"🔥",color:"#F4756A",goal:500,unit:"Cal",category:"Salud",health:"energy"),
        .init(id:"weight",name:"Registrar peso",icon:"⚖️",color:"#3BD6BE",goal:1,unit:"kg",category:"Salud",health:"weight"),
        .init(id:"read",name:"Leer un libro",icon:"📚",color:"#5CBAF0",goal:30,unit:"min",category:"Aprender"),
        .init(id:"journal",name:"Escribir un diario",icon:"📝",color:"#EC88B5",goal:1,unit:"veces",category:"Bienestar"),
        .init(id:"gratitude",name:"Agradecer",icon:"🙏",color:"#7D8796",goal:1,unit:"veces",category:"Bienestar"),
        .init(id:"language",name:"Aprender un idioma",icon:"🗣️",color:"#7895E0",goal:20,unit:"min",category:"Aprender"),
        .init(id:"study",name:"Estudiar",icon:"🧠",color:"#F4B357",goal:45,unit:"min",category:"Aprender"),
        .init(id:"sun",name:"Salir al aire libre",icon:"☀️",color:"#F4B357",goal:20,unit:"min",category:"Bienestar",health:"sun"),
        .init(id:"fruit",name:"Comer fruta",icon:"🍎",color:"#F4756A",goal:2,unit:"porciones",category:"Salud"),
        .init(id:"brush",name:"Cepillarse los dientes",icon:"🦷",color:"#76C8D0",goal:2,unit:"veces",category:"Salud"),
        .init(id:"tidy",name:"Ordenar la casa",icon:"🧹",color:"#D4A37C",goal:15,unit:"min",category:"Rutina"),
        .init(id:"plan",name:"Planear el día",icon:"🎯",color:"#EC88B5",goal:1,unit:"veces",category:"Rutina"),
        .init(id:"smoking",name:"Dejar de fumar",icon:"🚭",color:"#7D8796",goal:0,unit:"cigarrillos",category:"Dejar hábitos",type:"quit"),
        .init(id:"phone",name:"Reducir redes sociales",icon:"📵",color:"#7895E0",goal:30,unit:"min",category:"Dejar hábitos",type:"quit"),
        .init(id:"coffee",name:"Limitar el café",icon:"☕",color:"#D4A37C",goal:1,unit:"tazas",category:"Dejar hábitos",type:"quit")
    ]
}
struct HabitCatalog: View {
    @EnvironmentObject var store:HabitStore
    @Environment(\.dismiss) var dismiss
    @State private var didSave = false
    @State private var category = "Popular"
    @State private var search = ""
    @State private var draft:Habit? = nil
    @State private var suggestion:String? = nil
    private let categories = ["Popular","Salud","Deportes","Bienestar","Aprender","Rutina","Dejar hábitos"]
    var templates:[HabitTemplate] { HabitTemplate.all.filter { (category == "Popular" || $0.category == category) && (search.isEmpty || $0.name.localizedCaseInsensitiveContains(search)) } }
    var body:some View {
        NavigationStack {
            ScrollView {
                VStack(spacing:18) {

                    ScrollView(.horizontal,showsIndicators:false) { HStack(spacing:10) { ForEach(categories,id:\.self) { c in Button { category = c } label: { HStack(spacing:6) { if c == "Salud" { Image(systemName:"heart.fill") }; Text(c) }.font(.subheadline).foregroundStyle(c == category ? Color.white : Color.primary).padding(.horizontal,20).padding(.vertical,10).background(c == category ? Color.repeatPink : Color(.secondarySystemGroupedBackground),in:Capsule()) } } } }.padding(.bottom,8)
                    ForEach(templates) { template in Button { suggestion = template.health; let h = template.make(order:nextOrder); draft = h } label: { HStack(spacing:15) { Text(template.icon).font(.system(size:29)); Text(template.name).font(.system(size:17)); Spacer(); if template.health != nil { Image(systemName:"heart.fill").font(.caption).foregroundStyle(Color.repeatPink) }; Image(systemName:"plus").font(.title3) }.padding(20).background(Color(.secondarySystemGroupedBackground),in:Capsule()) }.buttonStyle(.plain) }
                    if templates.isEmpty { ContentUnavailableView.search(text:search) }
                }.padding(22).padding(.bottom,70)
            }.background(Color(.systemGroupedBackground)).navigationTitle("Nuevo hábito").navigationBarTitleDisplayMode(.inline)
            .searchable(text:$search,prompt:"Buscar una idea")
            .safeAreaInset(edge:.bottom) { Button { var h = Habit(); h.icon = "🌟"; h.color = "#3BD6BE"; h.order = nextOrder; h.memoAfter = true; suggestion = nil; draft = EditorDraft.newDrafts().first(where:{ saved in !store.state.snapshot.habits.contains(where:{$0.id == saved.habit.id}) })?.habit ?? h } label: { Text("Hábito personalizado").fontWeight(.semibold).padding(.horizontal,24).padding(.vertical,12) }.buttonStyle(.borderedProminent).clipShape(Capsule()).padding(.bottom,14) }
            .toolbar { ToolbarItem(placement:.cancellationAction) { Button("Cerrar") { dismiss() } } }
            .sheet(item:$draft,onDismiss:{ if didSave { dismiss() } }) { habit in HabitEditor(initial:habit,suggestedHealth:suggestion,isNew:true,onSaved:{ h in didSave = true }); }
        }
    }
    var nextOrder:Int { (store.state.snapshot.habits.map(\.order).max() ?? -1)+1 }
}
