import Foundation
import Testing
@testable import SixthSeat

@Suite("TableConfiguration")
struct TableConfigurationTests {

    @Test("All three tables expose non-empty ante and trips cycles")
    func cyclesAreNonEmpty() {
        for config in TableConfig.all {
            #expect(!config.anteCycle.isEmpty, "anteCycle empty for \(config.id)")
            #expect(!config.tripsCycle.isEmpty, "tripsCycle empty for \(config.id)")
        }
    }

    @Test("Every ante cycle ends with the cleared $0 position")
    func anteCyclesEndAtZero() {
        for config in TableConfig.all {
            #expect(config.anteCycle.last == 0, "\(config.id) ante cycle should end at 0")
        }
    }

    @Test("Every trips cycle starts with the off / $0 position")
    func tripsCyclesStartAtZero() {
        for config in TableConfig.all {
            #expect(config.tripsCycle.first == 0, "\(config.id) trips cycle should start at 0")
        }
    }

    @Test("minimumAnte equals the first non-zero entry in anteCycle")
    func minimumAnteMatchesFirstNonZeroAnteStep() {
        for config in TableConfig.all {
            let firstNonZero = config.anteCycle.first(where: { $0 > 0 })
            #expect(config.minimumAnte == firstNonZero, "\(config.id) minimumAnte mismatch")
        }
    }

    @Test("Every ante cycle value is a multiple of GameConstants.minimumChipValue")
    func anteCycleValuesRespectMinimumChip() {
        for config in TableConfig.all {
            for step in config.anteCycle {
                #expect(
                    step % GameConstants.minimumChipValue == 0,
                    "\(config.id) ante step \(step) not a multiple of \(GameConstants.minimumChipValue)"
                )
            }
        }
    }

    @Test("TableConfig.all has exactly the three V1 tables")
    func allTablesCountIsThree() {
        #expect(TableConfig.all.count == 3)
    }

    @Test("Table ids are unique across the registry")
    func tableIDsAreUnique() {
        let ids = TableConfig.all.map(\.id)
        #expect(Set(ids).count == ids.count)
    }

    @Test("Each table's id round-trips through Codable")
    func tableIDRoundTripsThroughCodable() throws {
        let encoder = JSONEncoder()
        let decoder = JSONDecoder()

        for config in TableConfig.all {
            let data = try encoder.encode(config)
            let decoded = try decoder.decode(TableConfig.self, from: data)
            #expect(decoded == config)
            #expect(decoded.id == config.id)
        }
    }

    @Test("defaultTable is the $10 table")
    func defaultTableIsTenDollar() {
        #expect(TableConfig.defaultTable.id == "table_10")
        #expect(TableConfig.defaultTable.minimumAnte == 10)
    }

    @Test("table(forID:) restores a known table by id")
    func tableLookupRestoresKnownID() {
        #expect(TableConfig.table(forID: "table_25") == .table25)
        #expect(TableConfig.table(forID: "table_50") == .table50)
        #expect(TableConfig.table(forID: "table_10") == .table10)
    }

    @Test("table(forID:) falls back to the default for nil or unknown ids")
    func tableLookupFallsBack() {
        #expect(TableConfig.table(forID: nil) == .defaultTable)
        #expect(TableConfig.table(forID: "table_999") == .defaultTable)
    }

    @Test("minimumEntryBalance is 6× the table minimum ante")
    func minimumEntryBalanceMatchesAffordabilityGate() {
        #expect(TableConfig.table10.minimumEntryBalance == 60)
        #expect(TableConfig.table25.minimumEntryBalance == 150)
        #expect(TableConfig.table50.minimumEntryBalance == 300)
    }

    @Test("anteRangeDescription spans smallest non-zero to largest non-zero step")
    func anteRangeDescriptionIsCorrect() {
        #expect(TableConfig.table10.anteRangeDescription == "$10 – $100")
        #expect(TableConfig.table25.anteRangeDescription == "$25 – $500")
        #expect(TableConfig.table50.anteRangeDescription == "$50 – $1000")
    }

    @Test("minimumTripsStep is the smallest non-zero entry in tripsCycle")
    func minimumTripsStepDerivedCorrectly() {
        #expect(TableConfig.table10.minimumTripsStep == 5)
        #expect(TableConfig.table25.minimumTripsStep == 5)
        #expect(TableConfig.table50.minimumTripsStep == 10)
    }
}
