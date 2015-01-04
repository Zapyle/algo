'use strict';

var assert = require('assert');

var dijkstra = require('./dijkstra.js');

var tests = [
    {
        graph: {
            vertexCount: 1,
            edges: [],
        },
        problems: [
            {start: 0, end: 0, solution: [0]}
        ]
    },
    {
        graph: {
            vertexCount: 2,
            edges: [
                {x: 0, y: 1, distance: 7},
            ]
        },
        problems: [
            {start: 0, end: 1, solution: [0, 1]}
        ]
    },
    {
        graph: {
            vertexCount: 2,
            edges: []
        },
        problems: [
            {start: 0, end: 1, solution: null}
        ]
    },
    {
        graph: {
            vertexCount: 6,
            edges: [
                {x: 0, y: 1, distance: 7},
                {x: 0, y: 2, distance: 9},
                {x: 0, y: 5, distance: 14},
                {x: 1, y: 2, distance: 10},
                {x: 1, y: 3, distance: 15},
                {x: 2, y: 3, distance: 11},
                {x: 2, y: 5, distance: 2},
                {x: 3, y: 4, distance: 6},
                {x: 4, y: 5, distance: 9}
            ]
        },
        problems: [
            // Refer to http://en.wikipedia.org/wiki/Dijkstra%27s_algorithm for an animated
            // illustration of Dijkstra's algorithm solving this example.
            {start: 0, end: 4, solution: [0, 2, 5, 4]}
        ]
    }
];

function runTest(test) {
    test.problems.forEach(function(problem) {
        var solution = dijkstra(test.graph, problem.start, problem.end);
        assert.deepEqual(solution, problem.solution);
    });
}

tests.forEach(runTest);

console.log('All tests OK.');
