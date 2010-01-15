drop table unkeyed_tests;
drop table keyed_tests;

create table unkeyed_tests (
	`id` int unique auto_increment, 
	`key` varchar(255), 
	`value` varchar(255), 
	created_at datetime, 
	updated_at datetime);
	
create table keyed_tests (
	`id` int unique auto_increment, 
	`key` varchar(255), 
	`value` varchar(255), 
	created_at datetime, 
	updated_at datetime);
	
create index index_key on keyed_tests(`key`);

insert into unkeyed_tests(`key`,value) values ('1','1234');
insert into unkeyed_tests(`key`,value) values ('2','1234');
insert into unkeyed_tests(`key`,value) values ('3','1234');
insert into unkeyed_tests(`key`,value) values ('4','1234');
insert into unkeyed_tests(`key`,value) values ('5','1234');
insert into unkeyed_tests(`key`,value) values ('6','1234');