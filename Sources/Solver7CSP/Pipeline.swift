import Foundation


public class Stage {

    let _name: String

    var name : String {
        get {
            _name
        }
    }

    let inputs: [Closeable]

    let outputs: [Closeable]

    let tc: ThreadContext

    init(name: String, inputs: [Closeable], outputs: [Closeable], tc: ThreadContext) {
        self._name = name
        self.inputs = inputs
        self.outputs = outputs
        self.tc = tc
    }

    public func close(timeoutAt: inout timespec) -> Int32 {
         if inputs.count != 0 {
             for closeable in inputs {
                 closeable.close()
             }
         }
         return tc.join(&timeoutAt)
    }


}

public class Pipeline {

    var stages : [String: Stage] = [:]

    var vertices: [String:StageVertex] = [:]

    var tops: [StageVertex] = []

    var chReaders: [String: StageVertexArray] = [:]
    var chWriters: [String: StageVertexArray] = [:]

    class StageVertexArray {
        var stages : [StageVertex] = []
        func add(_ vertex: StageVertex) {
            stages.append(vertex)
        }
    }
    var topologicalOrder: [StageVertex] = []

    public init() {

    }

    public func close(timeoutAt: inout timespec) -> Int32 {
        for stageVertex in topologicalOrder {
            let stage = stages[stageVertex.name]!
            let r = stage.close(timeoutAt: &timeoutAt)
            if r != 0 {
                return r
            }
        }
        return 0
    }

    public func add(stage: Stage) {
        stages[stage.name] = stage
        let stageVertex = StageVertex(name: stage.name)
        vertices[stageVertex.name] = stageVertex
        for ch in stage.outputs {
            let writers = chWriters[ch.getId(), default: StageVertexArray()]
            writers.add(stageVertex)
            chWriters[ch.getId()] = writers
        }
        if stage.inputs.count > 0 {
            for ch in stage.inputs {
                let readers = chReaders[ch.getId(), default: StageVertexArray()]
                readers.add(stageVertex)
                chReaders[ch.getId()] = readers
            }
        } else {
            tops.append(stageVertex)
        }

    }

    public func build() -> Void {
        //   (W0) -> ch1 <-  (R1 , W1) -> ch2 <- (R2, W3) -> ch3 <- (R3)
        //                       , W2) -> ch3 <--------------------
        //           E1                  E2                 E3
        //                                       E4
        for writers in chWriters {
            let name = writers.key
            if let readers = chReaders[name] {
                for writer in writers.value.stages {
                    for reader in readers.stages {
                        let edge = StageEdge(channelName: name, from: writer, to: reader)
                        writer.addOutput(edge)
                        reader.addInput(edge)
                    }
                }
            } else {
                fatalError("Can't have this")
            }
        }
    }

    func copyVertices() -> [String:StageVertex] {
        let pipeline = Pipeline()
        for stage in stages.values {
            pipeline.add(stage: stage)
        }
        pipeline.build()
        return pipeline.vertices
    }

    private var visited : [String:StageVertex] = [:]
    private var color : [String:Color] = [:]

    public func dfs(callback: @escaping (_ v: StageVertex)->Bool, detectCycle: Bool = true) throws {
        visited.removeAll()
        color.removeAll()
        for top in tops {
            try dfs(vertex: top, callback: callback, detectCycle: detectCycle)
        }
    }

    public enum CycleError : Error {
        case found
    }

    enum Color {
        case white, gray, black
    }

    func dfs(vertex: StageVertex,callback: (_ v:StageVertex)->Bool, detectCycle: Bool ) throws -> Bool {
        visited[vertex.name] = vertex
        if let currentColor = color[vertex.name] {
            if detectCycle && currentColor==Color.gray {
                throw CycleError.found
            }
        }
        color[vertex.name] = Color.gray
        for edge in vertex.outputs.values {
            if visited[edge.to.name] == nil {
                let c = try dfs(vertex: edge.to, callback: callback, detectCycle: detectCycle)
                if c == false {
                    return false
                }
            }
        }
        color[vertex.name] = Color.black
        return callback(vertex)
    }

    public func sortTopologically() {
        // todo: do a DFS on the graph and see if we have any cycles, should any cycles be allowed ?
        topologicalOrder.removeAll()
        var reducedGraph = copyVertices()
        var toRemove: [StageVertex] = []
        while reducedGraph.count > 0 {
            for stage in reducedGraph.values {
                if stage.inputs.count == 0 {
                    toRemove.append(stage)
                }
            }
            if toRemove.count == 0 {
                fatalError("Must have a cycle")
            }
            for stageToRemove in toRemove {
                topologicalOrder.append(stageToRemove)
                reducedGraph.removeValue(forKey: stageToRemove.name)
                for edge in stageToRemove.outputs.values {
                    let pointsTo = edge.to
                    if !pointsTo.removeMatchingInput(toFind: edge) {
                        print("oops")
                    }
                }
            }
            toRemove.removeAll()
        }
    }

    public func getTopologicalOrder() -> [String] {
        var order :[String] = []
        for sv in topologicalOrder {
            order.append(sv.name)
        }
        return order
    }

    public func showTopologicalOrder() {
        for stage in topologicalOrder {
            print(stage.name)
        }
    }
}


public class StageVertex : Hashable {

    let name: String
    var inputs: [String:StageEdge] = [:]
    var outputs: [String:StageEdge] = [:]

    init(name: String) {
        self.name = name
    }

    func addInput(_ edge: StageEdge) {
        inputs[edge.key] = edge
    }

    func addOutput(_ edge: StageEdge) {
        outputs[edge.key] = edge
    }

    func removeMatchingInput(toFind: StageEdge) -> Bool {
        inputs.removeValue(forKey: toFind.key) != nil
    }

    public static func ==(lhs: StageVertex, rhs: StageVertex) -> Bool {
        lhs === rhs
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(ObjectIdentifier(self))
    }

}

public class StageEdge {
    let channelName: String

    let from : StageVertex

    let to : StageVertex

    var key:String {
        get {
            channelName + "-" + from.name + "-" + to.name
        }
    }
    init(channelName: String, from: StageVertex, to: StageVertex) {
        self.channelName = channelName
        self.from = from
        self.to = to
    }

}


