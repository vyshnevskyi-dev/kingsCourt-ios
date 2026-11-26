import SwiftUI

private let ink = Color(hex: "0B0D0C")
private let panel = Color(hex: "171A18")
private let lime = Color(hex: "C8FF2E")
private let mist = Color(hex: "A7ADA8")

struct StreetTeam: Identifiable, Hashable {
    let id: Int; let name: String; let district: String; let mark: String; let color: Color
    let played: Int; let points: Int; let form: [Bool]
}
struct LeagueMatch: Identifiable, Hashable {
    let id: Int; let home: StreetTeam; let away: StreetTeam; let time: String; let venue: String; let score: String?
}
enum LeagueData {
    static let names = ["North Forge", "Canal Eleven", "Brickline", "Night Shift", "Rail Yard", "East Borough", "Concrete Foxes", "Block 17", "Rooftop Union", "South Arcade", "Foundry FC", "Metro Wolves", "Dockside", "Grey Market", "Old Mill", "Lantern Crew", "Underpass", "Red Quarry", "Parkside", "Cinder Athletic", "West Gate", "Boiler Room", "Iron Steps", "Static Club", "River Estate", "Ashfield", "Corner House", "High Rise", "Tunnel Works", "Blacktop", "Yard Saints", "Last Stop"]
    static let colors: [Color] = [.green, .orange, .cyan, .pink, .yellow, .purple, .mint, .red]
    static let teams = names.enumerated().map { i, name in StreetTeam(id: i, name: name, district: "District \(i / 4 + 1)", mark: String(name.prefix(2)).uppercased(), color: colors[i % colors.count], played: 3, points: max(0, 9 - (i % 4) * 2), form: [i % 2 == 0, i % 3 != 0, i % 4 < 2]) }
    static let matches = stride(from: 0, to: 16, by: 2).map { i in LeagueMatch(id: i, home: teams[i], away: teams[i + 1], time: "\(18 + i / 4):\(i % 4 == 0 ? "00" : "30")", venue: ["The Cage", "Foundry Court", "Dock Yard", "Block 9"][i % 4], score: i < 6 ? "\(2 + i % 3) – \(i % 2)" : nil) }
}

struct ContentView: View {
    var body: some View {
        TabView {
            NavigationStack { HomeScreen() }.tabItem { Label("League", systemImage: "shield.lefthalf.filled") }
            NavigationStack { FixturesScreen() }.tabItem { Label("Matches", systemImage: "calendar") }
            NavigationStack { TeamsScreen() }.tabItem { Label("Teams", systemImage: "person.3.fill") }
            NavigationStack { ExploreScreen() }.tabItem { Label("Explore", systemImage: "square.grid.2x2.fill") }
        }.tint(lime).preferredColorScheme(.dark)
    }
}

struct HomeScreen: View {
    @State private var following = false
    var body: some View {
        ScrollView { VStack(spacing: 18) {
            ZStack(alignment: .bottomLeading) {
                Image("LeagueHero").resizable().scaledToFill().frame(height: 280).clipped()
                LinearGradient(colors: [.clear, ink.opacity(0.96)], startPoint: .top, endPoint: .bottom)
                VStack(alignment: .leading, spacing: 8) {
                    Text("CONCRETE LEAGUE · RAIN BEAT TIME").font(.caption.bold()).tracking(1.5).foregroundStyle(lime)
                    Text("32 teams. One city.\nNo borrowed glory.").font(.system(size: 30, weight: .black, design: .rounded))
                    Button(following ? "Following season" : "Follow season") { following.toggle() }.buttonStyle(LimeButtonStyle())
                }.padding(20)
            }.clipShape(RoundedRectangle(cornerRadius: 24))
            HStack(spacing: 10) { StatTile(value: "32", label: "TEAMS"); StatTile(value: "8", label: "DISTRICTS"); StatTile(value: "4", label: "COURTS") }
            SectionTitle(title: "Tonight", action: "All matches") { FixturesScreen() }
            ForEach(LeagueData.matches.prefix(3)) { match in NavigationLink(value: match) { MatchRow(match: match) }.buttonStyle(.plain) }
            SectionTitle(title: "The story", action: "Read") { NewsScreen() }
            NavigationLink { NewsScreen() } label: { FeatureCard(icon: "flame.fill", title: "Round of 32: no easy exits", subtitle: "Eight districts arrive at The Cage for opening night.") }.buttonStyle(.plain)
        }.padding() }.background(ink).navigationTitle("Rain Beat Time").navigationDestination(for: LeagueMatch.self) { MatchCentreScreen(match: $0) }
    }
}

struct FixturesScreen: View {
    @State private var round = "Round 1"
    var body: some View {
        List { Picker("Round", selection: $round) { ForEach(["Round 1", "Round 2", "Round 3"], id: \.self) { Text($0) } }.pickerStyle(.segmented).listRowBackground(ink)
            Section("Tonight · 28 November") { ForEach(LeagueData.matches) { match in NavigationLink(value: match) { MatchRow(match: match) } } }
        }.scrollContentBackground(.hidden).background(ink).navigationTitle("Matches").navigationDestination(for: LeagueMatch.self) { MatchCentreScreen(match: $0) }
    }
}

struct TeamsScreen: View {
    @State private var search = ""
    var filtered: [StreetTeam] { search.isEmpty ? LeagueData.teams : LeagueData.teams.filter { $0.name.localizedCaseInsensitiveContains(search) } }
    var body: some View {
        ScrollView { LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) { ForEach(filtered) { team in NavigationLink(value: team) { TeamTile(team: team) }.buttonStyle(.plain) } }.padding() }
            .background(ink).navigationTitle("32 Teams").searchable(text: $search, prompt: "Find a team").navigationDestination(for: StreetTeam.self) { TeamDetailScreen(team: $0) }
    }
}

struct TeamDetailScreen: View {
    let team: StreetTeam; @State private var followed = false
    var body: some View {
        ScrollView { VStack(spacing: 18) { TeamBadge(team: team, size: 110); Text(team.name).font(.largeTitle.weight(.black)); Text(team.district.uppercased()).font(.caption.bold()).tracking(2).foregroundStyle(mist)
            Button(followed ? "Following" : "Follow team") { followed.toggle() }.buttonStyle(LimeButtonStyle())
            HStack { StatTile(value: "2", label: "WINS"); StatTile(value: "7", label: "GOALS"); StatTile(value: "3", label: "PLAYED") }
            NavigationLink { SquadScreen(team: team) } label: { FeatureCard(icon: "person.3.fill", title: "Squad", subtitle: "8 registered players") }.buttonStyle(.plain)
            Text("Born between tower blocks and the old tram depot, \(team.name) play fast, direct football built around pressure and quick restarts.").foregroundStyle(mist).padding().background(panel, in: RoundedRectangle(cornerRadius: 18))
        }.padding() }.background(ink).navigationTitle(team.name).navigationBarTitleDisplayMode(.inline)
    }
}

struct SquadScreen: View {
    let team: StreetTeam
    let roles = ["Keeper", "Anchor", "Runner", "Playmaker", "Wing", "Forward", "Utility", "Captain"]
    let names = ["Mika Stone", "Noah Voss", "Ilya Cross", "Sam Vale", "Ari North", "Leo Flint", "Nico Reed", "Mara Lane"]
    var body: some View { List(Array(roles.enumerated()), id: \.offset) { i, role in HStack { TeamBadge(team: team, size: 42); VStack(alignment: .leading) { Text(names[i]).bold(); Text(role).font(.caption).foregroundStyle(mist) }; Spacer(); Text("#\(i + 1)").font(.title3.weight(.black)).foregroundStyle(lime) } }.scrollContentBackground(.hidden).background(ink).navigationTitle("Squad") }
}

struct MatchCentreScreen: View {
    let match: LeagueMatch; @State private var reminder = false
    var body: some View {
        ScrollView { VStack(spacing: 22) { Text(match.score == nil ? "UPCOMING" : "FULL TIME").font(.caption.bold()).tracking(2).foregroundStyle(lime)
            HStack { TeamHeader(team: match.home); Text(match.score ?? match.time).font(.system(size: 34, weight: .black, design: .monospaced)); TeamHeader(team: match.away) }
            Text(match.venue).foregroundStyle(mist); Button(reminder ? "Reminder set" : "Remind me") { reminder.toggle() }.buttonStyle(LimeButtonStyle())
            SectionTitle(title: "Timeline", action: "") { EmptyView() }
            ForEach([("12’", "First shot on target"), ("24’", "High press wins possession"), ("38’", "Goal from a quick restart")], id: \.0) { event in HStack { Text(event.0).foregroundStyle(lime).font(.headline.monospacedDigit()); Text(event.1); Spacer() }.padding().background(panel, in: RoundedRectangle(cornerRadius: 14)) }
            NavigationLink { VenueDetailScreen(name: match.venue) } label: { FeatureCard(icon: "mappin.and.ellipse", title: match.venue, subtitle: "Court guide and access") }.buttonStyle(.plain)
        }.padding() }.background(ink).navigationTitle("Match Centre").navigationBarTitleDisplayMode(.inline)
    }
}

struct ExploreScreen: View {
    var body: some View { List {
        NavigationLink { StandingsScreen() } label: { ExploreRow(icon: "list.number", title: "Group tables", subtitle: "Eight groups of four") }
        NavigationLink { BracketScreen() } label: { ExploreRow(icon: "square.grid.3x3.fill", title: "Knockout bracket", subtitle: "Path to the final") }
        NavigationLink { VenuesScreen() } label: { ExploreRow(icon: "mappin.and.ellipse", title: "Courts", subtitle: "Four city venues") }
        NavigationLink { NewsScreen() } label: { ExploreRow(icon: "newspaper.fill", title: "Stories", subtitle: "Reports and team profiles") }
        NavigationLink { FavouritesScreen() } label: { ExploreRow(icon: "star.fill", title: "My league", subtitle: "Saved teams and reminders") }
        NavigationLink { SettingsScreen() } label: { ExploreRow(icon: "gearshape.fill", title: "Settings", subtitle: "Notifications and information") }
    }.scrollContentBackground(.hidden).background(ink).navigationTitle("Explore") }
}

struct StandingsScreen: View {
    var body: some View { List(0..<8, id: \.self) { group in Section("Group \(group + 1)") { ForEach(Array(LeagueData.teams[(group * 4)..<(group * 4 + 4)].enumerated()), id: \.element.id) { rank, team in HStack { Text("\(rank + 1)").foregroundStyle(rank < 2 ? lime : mist).frame(width: 24); TeamBadge(team: team, size: 30); Text(team.name); Spacer(); Text("\(team.points) pts").bold() } } } }.scrollContentBackground(.hidden).background(ink).navigationTitle("Group Tables") }
}
struct BracketScreen: View {
    var body: some View { ScrollView(.horizontal) { HStack(alignment: .top, spacing: 24) { BracketColumn(title: "ROUND OF 16", teams: Array(LeagueData.teams.prefix(16))); BracketColumn(title: "QUARTER-FINALS", teams: Array(LeagueData.teams.prefix(8))); BracketColumn(title: "SEMI-FINALS", teams: Array(LeagueData.teams.prefix(4))); BracketColumn(title: "FINAL", teams: Array(LeagueData.teams.prefix(2))) }.padding() }.background(ink).navigationTitle("Knockout") }
}
struct VenuesScreen: View {
    let venues = ["The Cage", "Foundry Court", "Dock Yard", "Block 9"]
    var body: some View { List(venues, id: \.self) { name in NavigationLink { VenueDetailScreen(name: name) } label: { ExploreRow(icon: "sportscourt.fill", title: name, subtitle: "Floodlit 5-a-side court") } }.scrollContentBackground(.hidden).background(ink).navigationTitle("Courts") }
}
struct VenueDetailScreen: View {
    let name: String
    var body: some View { ScrollView { VStack(spacing: 18) { Image("LeagueHero").resizable().scaledToFill().frame(height: 220).clipped().clipShape(RoundedRectangle(cornerRadius: 22)); Text(name).font(.largeTitle.weight(.black)); Text("A compact floodlit court with covered spectator rail, accessible entrance and nearby public transport.").foregroundStyle(mist); HStack { StatTile(value: "180", label: "CAPACITY"); StatTile(value: "5v5", label: "FORMAT"); StatTile(value: "4", label: "MATCHES") } }.padding() }.background(ink).navigationTitle("Court Guide").navigationBarTitleDisplayMode(.inline) }
}
struct NewsScreen: View {
    let stories = ["Why the city needed a league of its own", "Five captains shaping opening night", "The courts: four places, four identities", "Group A arrives with something to prove"]
    var body: some View { List(stories, id: \.self) { title in VStack(alignment: .leading, spacing: 8) { Text(title).font(.headline); Text("4 min read · Concrete League desk").font(.caption).foregroundStyle(mist); Text("Original reporting from the teams, courts and volunteers behind this season.").foregroundStyle(mist) }.padding(.vertical, 8) }.scrollContentBackground(.hidden).background(ink).navigationTitle("Stories") }
}
struct FavouritesScreen: View {
    var body: some View { List(LeagueData.teams.prefix(3)) { team in HStack { TeamBadge(team: team, size: 44); VStack(alignment: .leading) { Text(team.name).bold(); Text("Following · match alerts on").font(.caption).foregroundStyle(mist) }; Spacer(); Image(systemName: "star.fill").foregroundStyle(lime) } }.scrollContentBackground(.hidden).background(ink).navigationTitle("My League") }
}
struct SettingsScreen: View {
    @State private var results = true; @State private var reminders = true
    var body: some View { Form { Section("Notifications") { Toggle("Match reminders", isOn: $reminders); Toggle("Final results", isOn: $results) }; Section("About") { LabeledContent("Season", value: "2026/27"); LabeledContent("Teams", value: "32"); Link("Privacy Policy", destination: URL(string: "https://telegra.ph/Kings-Court--Support--Privacy-08-05")!) }; Section { Text("Concrete League is a fictional tournament companion. It does not offer betting, prizes or real-money transactions.").font(.footnote).foregroundStyle(mist) } }.scrollContentBackground(.hidden).background(ink).navigationTitle("Settings") }
}

private struct TeamBadge: View { let team: StreetTeam; var size: CGFloat; var body: some View { ZStack { RoundedRectangle(cornerRadius: size * 0.25).fill(team.color.gradient); RoundedRectangle(cornerRadius: size * 0.25).stroke(.white.opacity(0.25)); Text(team.mark).font(.system(size: size * 0.3, weight: .black, design: .rounded)).foregroundStyle(ink) }.frame(width: size, height: size) } }
private struct TeamHeader: View { let team: StreetTeam; var body: some View { VStack { TeamBadge(team: team, size: 72); Text(team.name).font(.caption.bold()).multilineTextAlignment(.center).frame(width: 90) } } }
private struct TeamTile: View { let team: StreetTeam; var body: some View { VStack(alignment: .leading, spacing: 10) { TeamBadge(team: team, size: 60); Text(team.name).font(.headline).foregroundStyle(.white); Text(team.district.uppercased()).font(.caption2.bold()).foregroundStyle(mist) }.frame(maxWidth: .infinity, alignment: .leading).padding().background(panel, in: RoundedRectangle(cornerRadius: 18)) } }
private struct MatchRow: View { let match: LeagueMatch; var body: some View { HStack(spacing: 12) { VStack(alignment: .leading) { Text(match.home.name).bold(); Text(match.away.name).bold() }; Spacer(); VStack(alignment: .trailing) { Text(match.score ?? match.time).font(.headline.monospacedDigit()).foregroundStyle(match.score == nil ? lime : .white); Text(match.venue).font(.caption).foregroundStyle(mist) } }.padding(.vertical, 6) } }
private struct StatTile: View { let value: String; let label: String; var body: some View { VStack(spacing: 4) { Text(value).font(.title2.weight(.black)).foregroundStyle(lime); Text(label).font(.caption2.bold()).tracking(1).foregroundStyle(mist) }.frame(maxWidth: .infinity).padding(.vertical, 14).background(panel, in: RoundedRectangle(cornerRadius: 14)) } }
private struct FeatureCard: View { let icon: String; let title: String; let subtitle: String; var body: some View { HStack(spacing: 14) { Image(systemName: icon).font(.title2).foregroundStyle(lime).frame(width: 44, height: 44).background(lime.opacity(0.1), in: RoundedRectangle(cornerRadius: 12)); VStack(alignment: .leading) { Text(title).font(.headline).foregroundStyle(.white); Text(subtitle).font(.caption).foregroundStyle(mist) }; Spacer(); Image(systemName: "chevron.right").foregroundStyle(mist) }.padding().background(panel, in: RoundedRectangle(cornerRadius: 18)) } }
private struct ExploreRow: View { let icon: String; let title: String; let subtitle: String; var body: some View { HStack { Image(systemName: icon).foregroundStyle(lime).frame(width: 32); VStack(alignment: .leading) { Text(title).bold(); Text(subtitle).font(.caption).foregroundStyle(mist) } }.padding(.vertical, 7) } }
private struct SectionTitle<Destination: View>: View { let title: String; let action: String; @ViewBuilder var destination: Destination; var body: some View { HStack { Text(title).font(.title2.weight(.black)); Spacer(); if !action.isEmpty { NavigationLink(action) { destination }.font(.subheadline.bold()).foregroundStyle(lime) } } } }
private struct BracketColumn: View { let title: String; let teams: [StreetTeam]; var body: some View { VStack(alignment: .leading, spacing: 10) { Text(title).font(.caption.bold()).tracking(1).foregroundStyle(lime); ForEach(teams) { team in HStack { TeamBadge(team: team, size: 30); Text(team.name).font(.caption.bold()); Spacer() }.padding(10).frame(width: 190).background(panel, in: RoundedRectangle(cornerRadius: 12)) } } } }
private struct LimeButtonStyle: ButtonStyle { func makeBody(configuration: Configuration) -> some View { configuration.label.font(.headline).foregroundStyle(ink).padding(.horizontal, 18).padding(.vertical, 12).background(lime.opacity(configuration.isPressed ? 0.7 : 1), in: Capsule()) } }
