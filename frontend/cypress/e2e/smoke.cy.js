describe("Public landing page", () => {
  it("renders the hero section", () => {
    cy.visit("/");
    cy.contains("Crie jornadas terapêuticas").should("be.visible");
    cy.contains("Começar agora").should("be.visible");
  });
});
