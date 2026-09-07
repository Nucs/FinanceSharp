using System;
using System.Linq;
using System.Runtime.CompilerServices;
using FinanceSharp.Indicators;
using FinanceSharp;
using FluentAssertions;
using NUnit.Framework;
using FinanceSharp.Tests.Helpers;

namespace FinanceSharp.Tests {
    public class DevTests {
        [Test]
        public unsafe void Dev() {
            var lhs = DoubleArray.ARange(0, 10, 1);
            lhs.AsDoubleSpan.ToArray().Should().BeEquivalentTo(0, 1, 2, 3, 4, 5, 6, 7, 8, 9);
            lhs.Properties.Should().Be(1);
            lhs.Count.Should().Be(10);
        }
    }
}