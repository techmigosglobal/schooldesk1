package routes

import (
	"os"
	"strings"
	"testing"
)

func TestTimetableRouteOwnershipAllowsPrincipalSmartGenerationAndManualSlotEdits(t *testing.T) {
	routesSource, err := os.ReadFile("routes.go")
	if err != nil {
		t.Fatalf("read routes.go: %v", err)
	}
	principalSource, err := os.ReadFile("principal_routes.go")
	if err != nil {
		t.Fatalf("read principal_routes.go: %v", err)
	}
	routes := string(routesSource)
	principalRoutes := string(principalSource)

	for _, expected := range []string{
		`timetable.POST("/slots/generate", middleware.RBACMiddleware("Admin")`,
		`timetable.POST("/slots", middleware.RBACMiddleware("Admin", "Principal")`,
		`timetable.PUT("/slots/:id", middleware.RBACMiddleware("Admin", "Principal")`,
		`timetable.DELETE("/slots/:id", middleware.RBACMiddleware("Admin")`,
		`timetable.PUT("/templates", middleware.RBACMiddleware("Admin")`,
		`timetable.POST("/smart/preview", middleware.RBACMiddleware("Admin", "Principal")`,
		`timetable.POST("/smart/generate", middleware.RBACMiddleware("Admin", "Principal")`,
	} {
		if !strings.Contains(routes, expected) {
			t.Fatalf("routes.go missing timetable route ownership %q", expected)
		}
	}
	for _, forbidden := range []string{
		`timetable.POST("/slots/generate", middleware.RBACMiddleware("Admin", "Principal")`,
		`timetable.DELETE("/slots/:id", middleware.RBACMiddleware("Admin", "Principal")`,
		`timetable.PUT("/templates", middleware.RBACMiddleware("Admin", "Principal")`,
	} {
		if strings.Contains(routes, forbidden) {
			t.Fatalf("routes.go still permits Principal timetable write route %q", forbidden)
		}
	}
	if !strings.Contains(principalRoutes, `principal.GET("/timetable"`) {
		t.Fatal("principal timetable overview route missing")
	}
	if !strings.Contains(principalRoutes, `"/timetable/actions"`) ||
		!strings.Contains(principalRoutes, "SaveTimetableAction") {
		t.Fatal("principal timetable action route missing")
	}
}
