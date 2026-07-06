import Foundation

/// Pure single-line nonogram solving: generates every clue placement
/// consistent with the current line state and deduces the cells shared by
/// all of them.
enum LineSolver {

    enum Result: Equatable {
        /// No placement satisfies the clues given the current line state.
        case contradiction
        /// The line with every cell forced by all valid placements set;
        /// cells the placements disagree on remain `.unmarked`.
        case deduced([TileState])
    }

    static func solve(line: [TileState], clues: [Int]) -> Result {
        let permutations = generateLinePermutations(currentLineState: line, clues: clues)
        guard !permutations.isEmpty else { return .contradiction }

        var deduced = line
        for index in 0..<line.count {
            let states = Set(permutations.map { $0[index] })
            if states.count == 1, let state = states.first {
                deduced[index] = state
            }
        }
        return .deduced(deduced)
    }

    static func generateLinePermutations(currentLineState: [TileState], clues: [Int]) -> [[TileState]] {
        var results: [[TileState]] = []
        let length = currentLineState.count

        func helper(_ index: Int, _ clueIndex: Int, _ line: [TileState]) {
            if clueIndex == clues.count {
                var candidate = line
                for i in index..<length {
                    if currentLineState[i] == .filled { return }
                    if candidate[i] == .unmarked { candidate[i] = .empty }
                }
                results.append(candidate)
                return
            }

            let clueLength = clues[clueIndex]
            let remainingClues = clues.suffix(from: clueIndex + 1)
            let minRemaining = remainingClues.reduce(0, +) + max(0, remainingClues.count)
            guard index + clueLength + minRemaining <= length else { return }

            for start in index...(length - clueLength - minRemaining) {
                var newLine = line
                var valid = true
                for pos in index..<start {
                    if currentLineState[pos] == .filled { valid = false; break }
                    if newLine[pos] == .unmarked { newLine[pos] = .empty }
                }
                if !valid { continue }

                for i in 0..<clueLength {
                    let pos = start + i
                    if currentLineState[pos] == .empty { valid = false; break }
                    newLine[pos] = .filled
                }
                if !valid { continue }

                var nextIndex = start + clueLength
                if clueIndex < clues.count - 1 {
                    if nextIndex >= length { continue }
                    if currentLineState[nextIndex] == .filled { continue }
                    if newLine[nextIndex] == .unmarked { newLine[nextIndex] = .empty }
                    nextIndex += 1
                }

                helper(nextIndex, clueIndex + 1, newLine)
            }
        }

        helper(0, 0, currentLineState)
        return results.filter { candidate in
            for i in 0..<length {
                if currentLineState[i] != .unmarked && candidate[i] != currentLineState[i] {
                    return false
                }
            }
            return true
        }
    }
}
