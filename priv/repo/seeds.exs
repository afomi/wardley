# Script for populating the database. You can run it as:
#
#     mix run priv/repo/seeds.exs
#
# Inside the script, you can read and write to any of your
# repositories directly:
#
#     Wardley.Repo.insert!(%Wardley.SomeSchema{})
#
# We recommend using the bang functions (`insert!`, `update!`
# and so on) as they will fail if something goes wrong.

alias Wardley.Repo
alias Wardley.Maps
alias Wardley.Maps.{Map, Node, Edge}
alias Wardley.Personas
alias Wardley.Personas.Persona

# Clear existing data (for re-seeding)
Repo.delete_all(Edge)
Repo.delete_all(Node)
Repo.delete_all(Map)
Repo.delete_all(Persona)

# =============================================================================
# Seed Data: Personas
#
# These represent different stakeholder types who interact with the value
# streams. "User" is the default generic persona; others represent specific
# roles within a public agency context.
# =============================================================================

# Default persona (always first)
_user = Personas.get_or_create_default_persona()

# Public-facing personas
{:ok, _citizen} = Personas.create_persona(%{
  name: "Citizen",
  description: "Residents who use city services directly",
  metadata: %{"category" => "external", "access_level" => "public"}
})

{:ok, _business_owner} = Personas.create_persona(%{
  name: "Business Owner",
  description: "Local business operators who need permits, licenses, and compliance",
  metadata: %{"category" => "external", "access_level" => "public"}
})

# Internal staff personas
{:ok, _frontline_staff} = Personas.create_persona(%{
  name: "Frontline Staff",
  description: "Employees who interact directly with citizens at service counters",
  metadata: %{"category" => "internal", "access_level" => "staff"}
})

{:ok, _caseworker} = Personas.create_persona(%{
  name: "Caseworker",
  description: "Staff who manage ongoing citizen cases and applications",
  metadata: %{"category" => "internal", "access_level" => "staff"}
})

{:ok, _department_manager} = Personas.create_persona(%{
  name: "Department Manager",
  description: "Managers overseeing departmental operations and staff",
  metadata: %{"category" => "internal", "access_level" => "management"}
})

# Executive/Governance personas
{:ok, _executive} = Personas.create_persona(%{
  name: "Executive",
  description: "City leadership (City Manager, Directors) making strategic decisions",
  metadata: %{"category" => "internal", "access_level" => "executive"}
})

{:ok, _elected_official} = Personas.create_persona(%{
  name: "Elected Official",
  description: "Mayor, Council members with policy and budget authority",
  metadata: %{"category" => "governance", "access_level" => "elected"}
})

# Technical personas
{:ok, _it_staff} = Personas.create_persona(%{
  name: "IT Staff",
  description: "Technical staff maintaining systems and infrastructure",
  metadata: %{"category" => "internal", "access_level" => "technical"}
})

{:ok, _analyst} = Personas.create_persona(%{
  name: "Analyst",
  description: "Staff who analyze data, create reports, and inform decisions",
  metadata: %{"category" => "internal", "access_level" => "staff"}
})

IO.puts("Seeded: #{Repo.aggregate(Persona, :count)} personas")

# =============================================================================
# Seed Data: City Citizen Services Portal
#
# This represents a public agency's value chain for delivering citizen services.
# The map illustrates components from user-visible services down to underlying
# infrastructure, positioned along the evolution axis (Genesis → Commodity).
# =============================================================================

map = Repo.insert!(%Map{name: "Citizen Services Portal"})

# Helper to create nodes with consistent structure
# x_pct: Evolution (0=Genesis, 100=Commodity)
# y_pct: Visibility (0=Invisible/Infrastructure, 100=User-facing)
create_node = fn text, x_pct, y_pct, metadata ->
  Repo.insert!(%Node{
    map_id: map.id,
    text: text,
    x_pct: x_pct,
    y_pct: y_pct,
    metadata: metadata
  })
end

# -----------------------------------------------------------------------------
# User-Facing Services (High Visibility: 80-100%)
# -----------------------------------------------------------------------------

citizen = create_node.("Citizen", 90.0, 98.0, %{
  "type" => "user",
  "description" => "Primary user of city services"
})

online_portal = create_node.("Online Portal", 65.0, 90.0, %{
  "type" => "service",
  "category" => "Web Application",
  "description" => "Main website for citizen service access"
})

mobile_app = create_node.("Mobile App", 55.0, 88.0, %{
  "type" => "service",
  "category" => "Mobile Application",
  "description" => "iOS/Android app for service access"
})

in_person = create_node.("In-Person Service", 85.0, 85.0, %{
  "type" => "service",
  "description" => "Walk-in service centers"
})

# -----------------------------------------------------------------------------
# Core Services (Visibility: 60-80%)
# -----------------------------------------------------------------------------

permit_system = create_node.("Permit Application", 45.0, 75.0, %{
  "type" => "service",
  "category" => "Business Process",
  "description" => "Building permits, business licenses, etc."
})

payment_processing = create_node.("Payment Processing", 80.0, 70.0, %{
  "type" => "service",
  "category" => "Financial",
  "description" => "Accept payments for fees, taxes, fines"
})

case_management = create_node.("Case Management", 40.0, 68.0, %{
  "type" => "service",
  "category" => "Business Process",
  "description" => "Track citizen requests and complaints"
})

notification_service = create_node.("Notifications", 70.0, 65.0, %{
  "type" => "service",
  "category" => "Communication",
  "description" => "Email, SMS alerts to citizens"
})

# -----------------------------------------------------------------------------
# Business Logic Layer (Visibility: 40-60%)
# -----------------------------------------------------------------------------

eligibility_engine = create_node.("Eligibility Engine", 25.0, 55.0, %{
  "type" => "component",
  "category" => "Business Rules",
  "description" => "Determines benefit/permit eligibility",
  "automation_potential" => "high"
})

workflow_engine = create_node.("Workflow Engine", 50.0, 50.0, %{
  "type" => "component",
  "category" => "Business Rules",
  "description" => "Routes work through approval chains"
})

document_management = create_node.("Document Management", 55.0, 48.0, %{
  "type" => "component",
  "category" => "Content Management",
  "tags" => ["CMS"]
})

reporting = create_node.("Reporting & Analytics", 60.0, 45.0, %{
  "type" => "component",
  "category" => "Analytics",
  "description" => "Dashboards, KPIs, compliance reports"
})

# -----------------------------------------------------------------------------
# Integration Layer (Visibility: 25-40%)
# -----------------------------------------------------------------------------

api_gateway = create_node.("API Gateway", 70.0, 38.0, %{
  "type" => "infrastructure",
  "category" => "Integration"
})

identity_provider = create_node.("Identity & Auth", 75.0, 35.0, %{
  "type" => "infrastructure",
  "category" => "Security",
  "tags" => ["IAM", "SSO"]
})

state_integration = create_node.("State Systems Integration", 30.0, 32.0, %{
  "type" => "integration",
  "description" => "Connect to state DMV, health, etc."
})

# -----------------------------------------------------------------------------
# Data Layer (Visibility: 15-25%)
# -----------------------------------------------------------------------------

citizen_database = create_node.("Citizen Database", 65.0, 22.0, %{
  "type" => "data",
  "category" => "Database",
  "tags" => ["PostgreSQL", "PII"]
})

gis_system = create_node.("GIS / Mapping", 50.0, 20.0, %{
  "type" => "data",
  "category" => "Geospatial"
})

legacy_mainframe = create_node.("Legacy Mainframe", 15.0, 18.0, %{
  "type" => "data",
  "category" => "Legacy System",
  "description" => "COBOL-based property records",
  "technical_debt" => "high"
})

# -----------------------------------------------------------------------------
# Infrastructure (Visibility: 0-15%)
# -----------------------------------------------------------------------------

cloud_platform = create_node.("Cloud Platform", 85.0, 12.0, %{
  "type" => "infrastructure",
  "category" => "Cloud Platform",
  "tags" => ["AWS", "IaaS"]
})

network = create_node.("Network Infrastructure", 92.0, 8.0, %{
  "type" => "infrastructure",
  "category" => "Network"
})

power = create_node.("Power / Facilities", 95.0, 5.0, %{
  "type" => "infrastructure",
  "category" => "Utility"
})

# -----------------------------------------------------------------------------
# Edges: Value Chain Dependencies
# -----------------------------------------------------------------------------

create_edge = fn source, target, metadata ->
  Repo.insert!(%Edge{
    map_id: map.id,
    source_id: source.id,
    target_id: target.id,
    metadata: metadata
  })
end

# Citizen uses services
create_edge.(citizen, online_portal, %{"relationship" => "uses"})
create_edge.(citizen, mobile_app, %{"relationship" => "uses"})
create_edge.(citizen, in_person, %{"relationship" => "uses"})

# Portal/App depend on core services
create_edge.(online_portal, permit_system, %{"relationship" => "provides"})
create_edge.(online_portal, payment_processing, %{"relationship" => "provides"})
create_edge.(online_portal, case_management, %{"relationship" => "provides"})
create_edge.(mobile_app, permit_system, %{"relationship" => "provides"})
create_edge.(mobile_app, payment_processing, %{"relationship" => "provides"})
create_edge.(in_person, permit_system, %{"relationship" => "provides"})
create_edge.(in_person, case_management, %{"relationship" => "provides"})

# Core services depend on business logic
create_edge.(permit_system, eligibility_engine, %{"relationship" => "requires"})
create_edge.(permit_system, workflow_engine, %{"relationship" => "requires"})
create_edge.(permit_system, document_management, %{"relationship" => "requires"})
create_edge.(case_management, workflow_engine, %{"relationship" => "requires"})
create_edge.(case_management, notification_service, %{"relationship" => "triggers"})

# Business logic depends on integration
create_edge.(eligibility_engine, state_integration, %{"relationship" => "queries"})
create_edge.(eligibility_engine, citizen_database, %{"relationship" => "reads"})
create_edge.(workflow_engine, api_gateway, %{"relationship" => "uses"})
create_edge.(notification_service, api_gateway, %{"relationship" => "uses"})
create_edge.(reporting, citizen_database, %{"relationship" => "reads"})

# Integration/Data layer dependencies
create_edge.(api_gateway, identity_provider, %{"relationship" => "authenticates"})
create_edge.(online_portal, identity_provider, %{"relationship" => "authenticates"})
create_edge.(mobile_app, identity_provider, %{"relationship" => "authenticates"})
create_edge.(permit_system, gis_system, %{"relationship" => "queries"})
create_edge.(eligibility_engine, legacy_mainframe, %{"relationship" => "queries"})

# Data layer depends on infrastructure
create_edge.(citizen_database, cloud_platform, %{"relationship" => "hosted_on"})
create_edge.(gis_system, cloud_platform, %{"relationship" => "hosted_on"})
create_edge.(api_gateway, cloud_platform, %{"relationship" => "hosted_on"})
create_edge.(identity_provider, cloud_platform, %{"relationship" => "hosted_on"})

# Infrastructure chain
create_edge.(cloud_platform, network, %{"relationship" => "requires"})
create_edge.(network, power, %{"relationship" => "requires"})
create_edge.(legacy_mainframe, power, %{"relationship" => "requires"})

IO.puts("Seeded: #{map.name}")
IO.puts("  - #{length(Maps.list_nodes(map.id))} nodes")
IO.puts("  - #{length(Maps.list_edges(map.id))} edges")

# =============================================================================
# Seed Data: Parks & Recreation Department
#
# A second department map for the same organization. This enables testing
# aggregation views that group similar components across departments.
# Note: Some components overlap with Citizen Services (CMS, Cloud Platform, etc.)
# but may be at different evolution stages, showing organizational divergence.
# =============================================================================

map2 = Repo.insert!(%Map{name: "Parks & Recreation"})

create_node2 = fn text, x_pct, y_pct, metadata ->
  Repo.insert!(%Node{
    map_id: map2.id,
    text: text,
    x_pct: x_pct,
    y_pct: y_pct,
    metadata: metadata
  })
end

create_edge2 = fn source, target, metadata ->
  Repo.insert!(%Edge{
    map_id: map2.id,
    source_id: source.id,
    target_id: target.id,
    metadata: metadata
  })
end

# -----------------------------------------------------------------------------
# User-Facing (High Visibility: 80-100%)
# -----------------------------------------------------------------------------

resident = create_node2.("Resident", 90.0, 98.0, %{
  "type" => "user",
  "description" => "Park visitors and program participants"
})

parks_website = create_node2.("Parks Website", 70.0, 90.0, %{
  "type" => "service",
  "category" => "Web Application",
  "description" => "Information about parks, programs, reservations"
})

reservation_system = create_node2.("Facility Reservation", 50.0, 85.0, %{
  "type" => "service",
  "category" => "Business Process",
  "description" => "Book picnic shelters, sports fields, event spaces"
})

program_registration = create_node2.("Program Registration", 55.0, 82.0, %{
  "type" => "service",
  "category" => "Business Process",
  "description" => "Sign up for classes, camps, leagues"
})

# -----------------------------------------------------------------------------
# Core Services (Visibility: 60-80%)
# -----------------------------------------------------------------------------

payment_parks = create_node2.("Payment Processing", 82.0, 70.0, %{
  "type" => "service",
  "category" => "Financial",
  "description" => "Fees for reservations, programs, permits"
})

scheduling_engine = create_node2.("Scheduling Engine", 40.0, 65.0, %{
  "type" => "component",
  "category" => "Business Rules",
  "description" => "Manages availability, conflicts, waitlists"
})

notifications_parks = create_node2.("Notifications", 72.0, 62.0, %{
  "type" => "service",
  "category" => "Communication",
  "description" => "Reminders, cancellations, weather alerts"
})

# -----------------------------------------------------------------------------
# Business Logic Layer (Visibility: 40-60%)
# -----------------------------------------------------------------------------

cms_parks = create_node2.("Content Management", 45.0, 50.0, %{
  "type" => "component",
  "category" => "Content Management",
  "tags" => ["CMS", "WordPress"],
  "description" => "WordPress-based (differs from main portal)"
})

inventory_system = create_node2.("Equipment Inventory", 35.0, 48.0, %{
  "type" => "component",
  "category" => "Asset Management",
  "description" => "Track rental equipment, maintenance schedules"
})

reporting_parks = create_node2.("Reporting & Analytics", 55.0, 45.0, %{
  "type" => "component",
  "category" => "Analytics",
  "description" => "Usage stats, revenue, program outcomes"
})

# -----------------------------------------------------------------------------
# Integration Layer (Visibility: 25-40%)
# -----------------------------------------------------------------------------

api_gateway_parks = create_node2.("API Gateway", 68.0, 38.0, %{
  "type" => "infrastructure",
  "category" => "Integration"
})

identity_parks = create_node2.("Identity & Auth", 78.0, 35.0, %{
  "type" => "infrastructure",
  "category" => "Security",
  "tags" => ["IAM", "SSO"],
  "description" => "Shared with city SSO"
})

# -----------------------------------------------------------------------------
# Data Layer (Visibility: 15-25%)
# -----------------------------------------------------------------------------

parks_database = create_node2.("Parks Database", 62.0, 22.0, %{
  "type" => "data",
  "category" => "Database",
  "tags" => ["MySQL"]
})

gis_parks = create_node2.("GIS / Mapping", 52.0, 20.0, %{
  "type" => "data",
  "category" => "Geospatial",
  "description" => "Park boundaries, trail maps, facility locations"
})

# -----------------------------------------------------------------------------
# Infrastructure (Visibility: 0-15%)
# -----------------------------------------------------------------------------

cloud_parks = create_node2.("Cloud Platform", 80.0, 12.0, %{
  "type" => "infrastructure",
  "category" => "Cloud Platform",
  "tags" => ["Azure", "IaaS"],
  "description" => "Different cloud than main IT (Azure vs AWS)"
})

network_parks = create_node2.("Network Infrastructure", 92.0, 8.0, %{
  "type" => "infrastructure",
  "category" => "Network"
})

power_parks = create_node2.("Power / Facilities", 95.0, 5.0, %{
  "type" => "infrastructure",
  "category" => "Utility"
})

# -----------------------------------------------------------------------------
# Edges: Value Chain Dependencies
# -----------------------------------------------------------------------------

# Resident uses services
create_edge2.(resident, parks_website, %{"relationship" => "uses"})
create_edge2.(resident, reservation_system, %{"relationship" => "uses"})
create_edge2.(resident, program_registration, %{"relationship" => "uses"})

# Website provides access to systems
create_edge2.(parks_website, reservation_system, %{"relationship" => "provides"})
create_edge2.(parks_website, program_registration, %{"relationship" => "provides"})

# Reservations and programs depend on core services
create_edge2.(reservation_system, scheduling_engine, %{"relationship" => "requires"})
create_edge2.(reservation_system, payment_parks, %{"relationship" => "requires"})
create_edge2.(program_registration, scheduling_engine, %{"relationship" => "requires"})
create_edge2.(program_registration, payment_parks, %{"relationship" => "requires"})
create_edge2.(program_registration, notifications_parks, %{"relationship" => "triggers"})

# Business logic dependencies
create_edge2.(parks_website, cms_parks, %{"relationship" => "powered_by"})
create_edge2.(scheduling_engine, inventory_system, %{"relationship" => "queries"})
create_edge2.(reporting_parks, parks_database, %{"relationship" => "reads"})
create_edge2.(notifications_parks, api_gateway_parks, %{"relationship" => "uses"})

# Integration layer
create_edge2.(api_gateway_parks, identity_parks, %{"relationship" => "authenticates"})
create_edge2.(parks_website, identity_parks, %{"relationship" => "authenticates"})
create_edge2.(reservation_system, gis_parks, %{"relationship" => "queries"})

# Data layer to infrastructure
create_edge2.(parks_database, cloud_parks, %{"relationship" => "hosted_on"})
create_edge2.(gis_parks, cloud_parks, %{"relationship" => "hosted_on"})
create_edge2.(api_gateway_parks, cloud_parks, %{"relationship" => "hosted_on"})
create_edge2.(cms_parks, cloud_parks, %{"relationship" => "hosted_on"})

# Infrastructure chain
create_edge2.(cloud_parks, network_parks, %{"relationship" => "requires"})
create_edge2.(network_parks, power_parks, %{"relationship" => "requires"})

IO.puts("Seeded: #{map2.name}")
IO.puts("  - #{length(Maps.list_nodes(map2.id))} nodes")
IO.puts("  - #{length(Maps.list_edges(map2.id))} edges")

# =============================================================================
# Summary: Cross-Map Component Alignment
#
# Components that appear in BOTH maps (for aggregation testing):
# - Payment Processing: Both at ~80% evolution (commodity)
# - Notifications: Both at ~70% evolution (product)
# - Content Management (CMS): 55% vs 45% evolution (divergence - Drupal vs WordPress)
# - GIS / Mapping: Both at ~50% evolution (product)
# - Identity & Auth: Both at ~75% evolution (commodity)
# - Cloud Platform: 85% vs 80% evolution (AWS vs Azure - accidental complexity)
# - API Gateway: Both at ~70% evolution (product)
# - Reporting & Analytics: 60% vs 55% evolution (similar)
# - Network Infrastructure: Both at ~92% evolution (commodity)
# - Power / Facilities: Both at ~95% evolution (utility)
#
# This demonstrates the "accidental complexity" problem: similar needs,
# different implementations, varying evolution assessments.
# =============================================================================

IO.puts("")
IO.puts("Total across all maps:")
IO.puts("  - #{Repo.aggregate(Node, :count)} nodes")
IO.puts("  - #{Repo.aggregate(Edge, :count)} edges")
