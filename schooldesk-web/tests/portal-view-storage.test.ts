import { expect, test } from "bun:test";
import { restorePortalValue } from "../lib/portal-view-storage";
test("nullable fee selections survive leaving and reloading their module", () => {
 expect(restorePortalValue<string|null>(JSON.stringify("section-id"),null)).toBe("section-id");
 expect(restorePortalValue<string|null>("null",null)).toBeNull();
 expect(restorePortalValue<string|null>('{"id":"record"}',null)).toBeNull();
});
test("corrupt or incompatible scoped UI state cannot replace filters", () => {
 const defaults={academic_year_id:"",grade_id:"",section_id:""};
 expect(restorePortalValue('{"academic_year_id":"year","grade_id":"grade","section_id":"section"}',defaults).grade_id).toBe("grade");
 expect(restorePortalValue('{"academic_year_id":{},"grade_id":"","section_id":""}',defaults)).toEqual(defaults);
 expect(restorePortalValue('"wrong-type"',1)).toBe(1);
 expect(restorePortalValue('broken',"all")).toBe("all");
});

test("expanded structure IDs survive remount without accepting record arrays", () => {
 expect(restorePortalValue('["structure-a","structure-b"]', [] as string[])).toEqual(["structure-a","structure-b"]);
 expect(restorePortalValue('[{"id":"record"}]', [] as string[])).toEqual([]);
});
