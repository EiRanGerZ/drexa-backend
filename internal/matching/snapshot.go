package matching

// BookLevel is one aggregated price level in a depth snapshot: the total
// remaining size (in lots) resting at a single tick price.
type BookLevel struct {
	Price    int64
	Quantity int64
}

// BookSnapshot is a point-in-time view of resting depth, best price first on
// each side: bids high→low, asks low→high.
type BookSnapshot struct {
	Bids []BookLevel
	Asks []BookLevel
}

// snapshot walks the book and returns up to depth levels per side, best price
// first. depth <= 0 returns every level.
//
// Not safe for concurrent use; the Engine holds the book lock around it.
func (ob *OrderBook) snapshot(depth int) BookSnapshot {
	snap := BookSnapshot{Bids: []BookLevel{}, Asks: []BookLevel{}}

	// Bids: best (highest) price first → walk the tree descending.
	bidIt := ob.bids.Iterator()
	for bidIt.End(); bidIt.Prev(); {
		if depth > 0 && len(snap.Bids) >= depth {
			break
		}
		lvl := bidIt.Value()
		snap.Bids = append(snap.Bids, BookLevel{Price: lvl.Price, Quantity: lvl.Volume()})
	}

	// Asks: best (lowest) price first → walk the tree ascending.
	askIt := ob.asks.Iterator()
	for askIt.Next() {
		if depth > 0 && len(snap.Asks) >= depth {
			break
		}
		lvl := askIt.Value()
		snap.Asks = append(snap.Asks, BookLevel{Price: lvl.Price, Quantity: lvl.Volume()})
	}

	return snap
}
