-- Data for Name: admins; Type: TABLE DATA; Schema: public; Owner: postgres
--

INSERT INTO "public"."admins" ("id", "user_id", "email", "role", "created_at", "is_active") VALUES
	('381f27ea-187a-4e53-bfbc-e160feb0630f', 'ADMIN3', 'masataka.tak@gmail.com', 'super_admin', '2025-06-17 14:21:23.84339+00', true),
	('13716eac-5520-4341-bbd8-2d2dbcf4550e', 'ADMIN2', 'basarasystems@gmail.com', 'admin', '2025-06-17 12:44:55.331184+00', true),
	('c1afe8d9-5f3d-4cc6-9210-709082a5dcfa', '14375a3b-1235-4721-92a7-c1df33b22edd', 'support@dshsupport.biz', 'admin', '2025-07-11 06:42:10.726502+00', true);


--
-- Data for Name: users; Type: TABLE DATA; Schema: public; Owner: postgres
