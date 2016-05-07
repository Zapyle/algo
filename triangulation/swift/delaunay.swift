// swiftlint:disable comma
// swiftlint:disable variable_name

class HalfEdge: CustomStringConvertible {
    var dirty = true // Used during flipping.

    var origin: Point
    var twin: HalfEdge!

    // Half-edges on the outside of the convex hull never have next half-edges.
    var next: HalfEdge?

    // Since we only handle triangulations, we don't need to store a pointer to the previous
    // half-edge.
    var prev: HalfEdge? {
        return self.next?.next
    }

    var locallyDelaunay: Bool {
        // Edges on the convex hull cannot be flipped and are considered locally delaunay for
        // simplicity.
        if next == nil || twin.next == nil {
            return true
        }

        // The triangles needs to be in counter-clockwise order.
        let triangle1 = (origin, next!.origin, prev!.origin)
        let opposite1 = twin.prev!.origin
        let triangle2 = (twin.origin, twin.next!.origin, twin.prev!.origin)
        let opposite2 = prev!.origin
        return !inCircumcircle(triangle1, point: opposite1) &&
            !inCircumcircle(triangle2, point: opposite2)
    }

    var description: String {
        return "\(origin) -> \(twin.origin)\(next == nil ? " without next" : "")"
    }

    init(origin: Point) {
        self.origin = origin
    }

    func flip() {
        // Only the half-edges inside the quadrilateral are changed; half-edges outside the
        // quadrilateral are unchanged, because the quadrilateral doesn't change shape after a flip.
        // This means we have 6 half-edges to update: self, next, prev, twin, twin.next and
        // twin.prev. I won't comment each update because the best way to figure it out is with a
        // before/after drawing.

        let n = next!
        let p = prev!
        let t = twin
        let tn = twin.next!
        let tp = twin.prev!

        origin = p.origin
        next = tp

        t.origin = tp.origin
        t.next = p

        n.next = self
        p.next = tn
        tn.next = t
        tp.next = n
    }
}

func determinant4x4(m: [Int]) -> Int {
    // Ugly and lifted from Stack Overflow, but:
    // - Calculating determinants is not the point of this module. For fancier calculation methods,
    //   see the `determinant` module.
    // - In this particular situation, we know that the matrix is always going to be 4x4, so a
    //   hardcoded formula is likely to be faster and less bug-prone than more general methods.
    return m[12] * m[9]  * m[6]  * m[3]   -  m[8] * m[13] * m[6]  * m[3]   -
           m[12] * m[5]  * m[10] * m[3]   +  m[4] * m[13] * m[10] * m[3]   +
           m[8]  * m[5]  * m[14] * m[3]   -  m[4] * m[9]  * m[14] * m[3]   -
           m[12] * m[9]  * m[2]  * m[7]   +  m[8] * m[13] * m[2]  * m[7]   +
           m[12] * m[1]  * m[10] * m[7]   -  m[0] * m[13] * m[10] * m[7]   -
           m[8]  * m[1]  * m[14] * m[7]   +  m[0] * m[9]  * m[14] * m[7]   +
           m[12] * m[5]  * m[2]  * m[11]  -  m[4] * m[13] * m[2]  * m[11]  -
           m[12] * m[1]  * m[6]  * m[11]  +  m[0] * m[13] * m[6]  * m[11]  +
           m[4]  * m[1]  * m[14] * m[11]  -  m[0] * m[5]  * m[14] * m[11]  -
           m[8]  * m[5]  * m[2]  * m[15]  +  m[4] * m[9]  * m[2]  * m[15]  +
           m[8]  * m[1]  * m[6]  * m[15]  -  m[0] * m[9]  * m[6]  * m[15]  -
           m[4]  * m[1]  * m[10] * m[15]  +  m[0] * m[5]  * m[10] * m[15]
}

func square(value: Int) -> Int {
    return value * value
}

func inCircumcircle(triangle: (Point, Point, Point), point: Point) -> Bool {
    return determinant4x4([
        triangle.0.0,   triangle.0.1,   square(triangle.0.0) + square(triangle.0.1),   1,
        triangle.1.0,   triangle.1.1,   square(triangle.1.0) + square(triangle.1.1),   1,
        triangle.2.0,   triangle.2.1,   square(triangle.2.0) + square(triangle.2.1),   1,
        point.0,        point.1,        square(point.0) + square(point.1),             1,
    ]) > 0
}

// Compare p1 and p2 based on the clockwise angle the rays origin->p1 and origin->p2 form relatively
// to the ray going straight up from origin (i.e. the "12 o'clock").
// We can ignore some edges cases because we know that for this application:
// - p1, p2 and origin are always distinct
// - if p1, p2 and origin are collinear then origin must be the middle point
func compareClockwise(p1: Point, lessThan p2: Point, origin: Point) -> Bool {
    // Handle case where p1 and p2 are not on the same vertical half of the plane.
    if p1.0 >= origin.0 && p2.0 < origin.0 {
        return true
    }
    if p2.0 >= origin.0 && p1.0 < origin.0 {
        return false
    }

    switch direction(p1, origin, p2) {
    case .Collinear:
        //  One of p1, p2 is on the "12 o'clock" and the other is on the "6 o'clock".
        return p1.1 > p2.1

    case .CounterClockwise:
        return true

    case .Clockwise:
        return false
    }
}

func doublyConnectedEdgeList(edges: [Edge]) -> [HalfEdge] {
    var halfEdges = [HalfEdge]()

    // Create all half-edges without setting their 'next' property yet, and keep a mapping between
    // origins and half-edges.
    for edge in edges {
        let a = HalfEdge(origin: edge.0)
        let b = HalfEdge(origin: edge.1)
        a.twin = b
        b.twin = a
        halfEdges += [a, b]
    }

    // Sort the half-edges by origin first, and then by clockwise order.
    halfEdges.sortInPlace {
        $0.origin < $1.origin || $0.origin == $1.origin &&
            compareClockwise($0.twin.origin, lessThan: $1.twin.origin, origin: $0.origin)
    }

    // For each pair (a, b) of half-edges with the same origin and in clockwise order, set the
    // 'next' property of a.twin to b. Remarks:
    // - We need to wrap and process the pair (last, first) of half-edges with the same origin.
    // - To avoid setting the 'next' property of half-edges that are on the outside of the convex
    //   hull, we need to check that the two half-edges form a triangle, i.e. that a-b form a
    //   counter-clockwise turn.
    var first = halfEdges[0]
    for i in 0..<halfEdges.count {
        let a = halfEdges[i]
        var b: HalfEdge!

        if i == halfEdges.count - 1 {
            b = first
        } else if halfEdges[i + 1].origin == a.origin {
            b = halfEdges[i + 1]
        } else {
            b = first
            first = halfEdges[i + 1]
        }

        if direction(a.twin.origin, a.origin, b.twin.origin) == .CounterClockwise {
            a.twin.next = b
        }
    }

    return halfEdges
}

func flipUntilDelaunay(halfEdges: [HalfEdge]) {
    var dirty = halfEdges

    while !dirty.isEmpty {
        let halfEdge = dirty.removeLast()
        halfEdge.dirty = false

        if halfEdge.locallyDelaunay {
            continue
        }

        halfEdge.flip()

        let neighbors = [halfEdge.next!, halfEdge.prev!, halfEdge.twin.next!, halfEdge.twin.prev!]
        for neighbor in neighbors where !neighbor.dirty {
            neighbor.dirty = true
            dirty.append(neighbor)
        }
    }
}

public func delaunay(triangulation: [Edge]) -> [Edge] {
    let halfEdges = doublyConnectedEdgeList(triangulation)
    flipUntilDelaunay(halfEdges)
    return deduplicate(halfEdges.map { ($0.origin, $0.twin.origin) })
}
