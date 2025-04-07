USE [DBA_Internal] /** Mention your Database here **/
GO

/****** Object:  StoredProcedure [dbo].[usp_Updating_Failover_Details_Table]   ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO


-- =============================================
-- Author:	Agoramoorthy N
-- Version : 1
-- Description:	Procedure  [dbo].[usp_Updating_Failover_Details_Table] to update Failover Table
-- =============================================
CREATE              PROCEDURE [dbo].[usp_Updating_Failover_Details_Table]
AS
BEGIN

	SET NOCOUNT ON;

DECLARE @Count_Original INT;
DECLARE @Count_Temp INT;
Declare @Temp_Table Table 
( object_name CHAR(50),event_timestamp Datetime,ag_name VARCHAR(50),
previous_state CHAR(100),current_State CHAR(100));



DECLARE @SUBJECT CHAR(100)
DECLARE @Temp CHAR(100)

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
Insert into @Temp_Table
	
	
	select
		object_name,
		event_timestamp = 
			dateadd(hour, @utc_adjustment, event_data.value('(event/@timestamp)[1]', 'datetime')),
		ag_name = 
			event_data.value('(event/data[@name = "availability_group_name"]/value)[1]', 'varchar(64)'),
		previous_state = 
			event_data.value('(event/data[@name = "previous_state"]/text)[1]', 'varchar(64)'),
		current_state = 
			event_data.value('(event/data[@name = "current_state"]/text)[1]', 'varchar(64)')
	from state_change_data
	where object_name = 'availability_replica_state_change'
	order by event_timestamp ;
	
--SELECT ag_name,event_timestamp,Previous_state,current_State FROM @Temp_Table order by event_timestamp desc;

SET @Count_Original =(SELECT COUNT(*) FROM [dbo].[Failover_Details])
SET @Count_Temp		=(SELECT COUNT(*) FROM @Temp_Table)

Select @Count_Original
Select @Count_Temp

If (@Count_Original < @Count_Temp )
BEGIN

	Truncate Table [dbo].[Failover_Details]


	INSERT INTO [dbo].[Failover_Details]
		SELECT * FROM @Temp_Table;

	BEGIN
  
	EXEC msdb.dbo.sp_start_job @job_name=N'**DBA_Failover_Alert' ;  
 
	END
END
END
GO

