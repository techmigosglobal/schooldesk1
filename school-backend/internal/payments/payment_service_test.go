package payments

import "testing"

func TestAllocatePaymentAcrossInvoiceBalances(t *testing.T) {
	allocations := allocatePaymentAcrossBalances(1500, []float64{1000, 500})

	if len(allocations) != 2 {
		t.Fatalf("allocations len=%d, want 2", len(allocations))
	}
	if allocations[0] != 1000 {
		t.Fatalf("first allocation=%v, want 1000", allocations[0])
	}
	if allocations[1] != 500 {
		t.Fatalf("second allocation=%v, want 500", allocations[1])
	}
}

func TestAllocatePaymentAcrossInvoiceBalancesStopsAtPaidAmount(t *testing.T) {
	allocations := allocatePaymentAcrossBalances(1200, []float64{1000, 500})

	if allocations[0] != 1000 {
		t.Fatalf("first allocation=%v, want 1000", allocations[0])
	}
	if allocations[1] != 200 {
		t.Fatalf("second allocation=%v, want 200", allocations[1])
	}
}
