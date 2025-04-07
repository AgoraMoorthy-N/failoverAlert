USE [DBA_Internal] /** Mention your database here **/
GO

/****** Object:  StoredProcedure [dbo].[Usp_Replica_Failover_Alert_SP]   ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO



-- ==========================================================================
-- Description:	Stored procedure Usp_Replica_Failover_Alert_SP For Failover
-- ==========================================================================
CREATE                     PROCEDURE [dbo].[Usp_Replica_Failover_Alert_SP]

as
Begin 

--============================================================================
----------------Delaclaration-------------------------------------------------
--============================================================================

Declare @Temp Table 
( object_name CHAR(50),event_timestamp Datetime,ag_name VARCHAR(50),previous_state CHAR(100),current_State CHAR(100));

Declare @AG_Alert Table
(ag_name CHAR(100),event_timestamp Datetime,previous_state CHAR(100),current_State CHAR(100),server_state VARCHAR(MAX));


 Declare @Temp_1 Table
(replica_id VARCHAR(100),group_id VARCHAR(100),is_local BIGINT,role_1 BIGINT,role_desc CHAR(20),Operational_state CHAR(20),
operational_state_desc CHAR(20),connected_state_1 BIGINT,connected_state_desc CHAR(50),recovery_health BIGINT,recovery_health_desc CHAR(20),
synchronization_health_1 BIGINT,synchronization_health_desc CHAR(50),Last_Connect_error_number CHAR(50),Last_connect_error_description CHAR(50),Last_connect_error_timestamp CHAR(50),
write_lease_remaining_ticks BIGINT,current_configuration_commit_start_time_utc DATETIME,group_id_1 VARCHAR(100),
name CHAR(25),resource_id VARCHAR(100),resource_group_id VARCHAR(100),failure_condition_level BIGINT,health_check_timeout BIGINT,automated_backup_preference BIGINT,
automated_backup_preference_desc CHAR(20),version BIGINT,basic_features BIGINT,dtc_support BIGINT,db_failover BIGINT,is_distributed BIGINT,
cluster_type BIGINT,cluster_type_desc CHAR(10),required_synchronized_secondaries_to_commit BIGINT,sequence_number BIGINT,is_contained BIGINT,
replica_id_1 VARCHAR(50),group_id_2 VARCHAR(50),replica_metadata_id BIGINT,replica_server_name CHAR(50),owner_sid VARCHAR(MAX),
endpoBIGINT_url VARCHAR(50),availability_mode BIGINT,availability_mode_desc CHAR(50),failover_mode BIGINT,failover_mode_desc CHAR(50),
session_timeout BIGINT,primary_role_allow_connections  BIGINT,primary_role_allow_connections_desc CHAR(10),secondary_role_allow_connections CHAR(10),secondary_role_allow_connections_desc CHAR(10),
create_date DATETIME,modify_date Datetime,backup_priority BIGINT,read_only_routing_url CHAR(10),seeding_mode BIGINT,
seeding_mode_desc CHAR(20),read_write_routing_url VARCHAR(10));


DECLARE @SUBJECT CHAR(100)
DECLARE @Restart_Time CHAR(100)
DECLARE @SQL_Version VARCHAR(25)
DECLARE @Product_Level CHAR(10)
DECLARE @ProductVersion CHAR(20)
DECLARE @Edition VARCHAR(30)
Declare @server_name CHAR(20)

Set @server_name = (SELECT @@servername )

declare @xel_path varchar(1024);
	declare @utc_adjustment int = datediff(hour, getutcdate(), getdate());

	-------------------------------------------------------------------------------
	------------------- target event_file path retrieval --------------------------
	-------------------------------------------------------------------------------
	;with target_data_cte as
	(
		select  
			target_data = 
				convert(xml, target_data)
		from sys.dm_xe_sessions s
		inner join sys.dm_xe_session_targets st
		on s.address = st.event_session_address
		where s.name = 'alwayson_health'
		and st.target_name = 'event_file'
	),
	full_path_cte as
	(
		select
			full_path = 
				target_data.value('(EventFileTarget/File/@name)[1]', 'varchar(1024)')
		from target_data_cte
	)
	select
		@xel_path = 
			left(full_path, len(full_path) - charindex('\', reverse(full_path))) + 
			'\AlwaysOn_health*.xel'
	from full_path_cte;

	-------------------------------------------------------------------------------
	------------------- replica state change events -------------------------------
	-------------------------------------------------------------------------------
	;with state_change_data as
	(
		select
			object_name,
			event_data = 
				convert(xml, event_data)
		from sys.fn_xe_file_target_read_file(@xel_path, null, null, null)
	)
Insert into @Temp
	
	
	select
		object_name,
		event_timestamp = 
			dateadd(hour, @utc_adjustment, event_data.value('(event/@timestamp)[1]', 'datetime')),
		ag_name = 
			event_data.value('(event/data[@name = "availability_group_name"]/value)[1]', 'varchar(64)'),
		previous_state = 
			event_data.value('(event/data[@name = "previous_state"]/text)[1]', 'varchar(64)'),
		current_State = 
			event_data.value('(event/data[@name = "current_state"]/text)[1]', 'varchar(64)')
	from state_change_data
	where object_name = 'availability_replica_state_change'
	order by event_timestamp ;

INSERT into @AG_Alert
		Select ag_name,event_timestamp,previous_state,current_State,
		CASE
			WHEN current_State= 'PRIMARY_NORMAL' THEN @server_name + ' Is Primary at this time'
			WHEN current_State= 'SECONDARY_NORMAL' THEN @server_name + ' Is Secondary at this time'
			ELSE 'NULL'
		END AS server_state
		FROM @Temp;

	
select * from @AG_Alert
INSERT INTO @Temp_1

	select *

	FROM sys.dm_hadr_availability_replica_states rs

	inner join sys.availability_groups ags

	on rs.group_id = ags.group_id

	inner join sys.availability_replicas r

	on r.replica_id = rs.replica_id



set @SUBJECT=' Failover Happend in ' +CAST(@@servername AS CHAR(20)) +' AT '+CAST(getdate() AS CHAR(25))
set @Restart_Time = CAST ((select sqlserver_start_time from sys.dm_os_sys_info) AS CHAR(100))
Set @SQL_Version = (SELECT
  CASE 
     WHEN CONVERT(VARCHAR(128), SERVERPROPERTY ('productversion')) like '8%' THEN 'SQL2000'
     WHEN CONVERT(VARCHAR(128), SERVERPROPERTY ('productversion')) like '9%' THEN 'SQL2005'
     WHEN CONVERT(VARCHAR(128), SERVERPROPERTY ('productversion')) like '10.0%' THEN 'SQL2008'
     WHEN CONVERT(VARCHAR(128), SERVERPROPERTY ('productversion')) like '10.5%' THEN 'SQL2008 R2'
     WHEN CONVERT(VARCHAR(128), SERVERPROPERTY ('productversion')) like '11%' THEN 'SQL2012'
     WHEN CONVERT(VARCHAR(128), SERVERPROPERTY ('productversion')) like '12%' THEN 'SQL2014'
     WHEN CONVERT(VARCHAR(128), SERVERPROPERTY ('productversion')) like '13%' THEN 'SQL2016'     
     WHEN CONVERT(VARCHAR(128), SERVERPROPERTY ('productversion')) like '14%' THEN 'SQL2017' 
     WHEN CONVERT(VARCHAR(128), SERVERPROPERTY ('productversion')) like '15%' THEN 'SQL2019' 
     WHEN CONVERT(VARCHAR(128), SERVERPROPERTY ('productversion')) like '16%' THEN 'SQL2022' 
     ELSE 'unknown'
  END AS SQL_Version)
set @Restart_Time = CAST ((select sqlserver_start_time from sys.dm_os_sys_info) AS CHAR(100))
set @Product_Level = CAST ((SELECT SERVERPROPERTY('ProductLevel') AS ProductLevel) AS CHAR(20))
SET @ProductVersion =CAST ((SELECT SERVERPROPERTY('ProductVersion') AS ProductVersion) AS CHAR(20))
SET @Edition = CAST ((SELECT SERVERPROPERTY('Edition') AS Edition) AS CHAR(30))


--=====================================================================================================
--HTML Statement for Table Creation
--=====================================================================================================

DECLARE @tableHTML_Total NVARCHAR(MAX) ;
DECLARE @tableHTML1 NVARCHAR(MAX) ;
DECLARE @tableHTML2 NVARCHAR(MAX);

--=====================================================================================================
--HTML Setup for Table-1
--=====================================================================================================

SET @tableHTML1 =
N'<H1 bgcolor="magenta">Last Failover details  </H1>' +
N'<table border="1">' +
N'<tr bgcolor="#45B39D"><th>AG_name</th><th>Failover_timestamp</th><th>Previous_State</th><th>current_State</th><th>server_state</th>'+


CAST ( ( SELECT TOP 1

td= ag_name,'',
td= event_timestamp,'',
td= previous_state,'',
td= current_State,'',
td=server_state,''
FROM @AG_Alert where server_state <> 'Null' order by event_timestamp desc
FOR XML PATH('tr'), TYPE )AS NVARCHAR(MAX))+N'</table>'

--============================================================================================
--HTML setup for Table-2
--============================================================================================

SET @tableHTML2 =
N'<H1 bgcolor="magenta">Always ON Details</H1>' +
N'<table border="1">' +
N'<tr bgcolor="#F3F00B"><th>name</th><th>Replica_server_name</th><th>Role</th><th>Connected_state</th><th>Synchronization_health</th><th>Seeding_mode</th><th>Failover_mode</th><th>Availability_mode</th>' +
CAST (

(SELECT 

td= name,'',
td= replica_server_name,'',
td= role_desc,'',
td= connected_state_desc,'',
td= synchronization_health_desc,'',
td= seeding_mode_desc,'',
td= failover_mode_desc,'',
td= availability_mode_desc,''
FROM @Temp_1
FOR XML PATH('tr'), TYPE

 ) AS NVARCHAR(MAX) ) + N'</table>' ;

--==========================================================================================
--HTML setup for Table-3
--==========================================================================================

Declare @tableHTML3 VARCHAR(MAX)

SET @tableHTML3 =
N'<H1 bgcolor="magenta">SQL Server Details</H1>' +
N'<table border="1">' +
N'<tr bgcolor="#23F705"><th>Server_name</th><th>SQL_Server_Start_Time</th><th>SQL_Version</th><th>Product_Level</th><th>Edition</th><th>ProductVersion</th>' +
CAST ( ( SELECT 
td= @server_name,'',
td= @Restart_Time,'',
td= @SQL_Version,'',
td= @Product_Level,'',
td= @ProductVersion,'',
td= @Edition,''
FOR XML PATH('tr'), TYPE )AS NVARCHAR(MAX)) + N'</table>' ;

--=================================================================================
--Adding HTML Tables into a master Table
--=================================================================================

SET @tableHTML_Total = @tableHTML1 + @tableHTML2+@tableHTML3;

END

/**send_dbmail_notification**/

EXEC msdb.dbo.sp_send_dbmail
@recipients='yourmail@example.com', /** Add your mail here **/
@profile_name = 'DBA_MAIL', /** Add your SQL mail profile here **/
@subject = @SUBJECT,
@body = @tableHTML_Total,@body_format = 'HTML';

GO

