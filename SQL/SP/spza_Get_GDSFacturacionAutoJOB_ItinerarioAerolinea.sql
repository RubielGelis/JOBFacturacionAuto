IF OBJECT_ID('dbo.spza_Get_GDSFacturacionAutoJOB_ItinerarioAerolinea', 'P') IS NOT NULL
    DROP PROCEDURE dbo.spza_Get_GDSFacturacionAutoJOB_ItinerarioAerolinea;
GO
CREATE PROCEDURE dbo.spza_Get_GDSFacturacionAutoJOB_ItinerarioAerolinea 
	-- Parametros del procedimiento
	@id_usuario INT,
	@cd_sucursal VARCHAR(MAX) = '',
	@cd_implante VARCHAR(MAX) = '' 

 
AS
BEGIN
	-- SET NOCOUNT ON: Previene que conjuntos de resultados extras interfieran con 
	-- expresiones SELECT
	SET NOCOUNT ON;

    -- Declaracion e inicializacion de variables
  	DECLARE @bl_permit			 BIT 	, -- Permiso de ejecucion del proceso
  			@bl_as 	   			 BIT	, -- Auditar exito
	 		@bl_af 			     BIT	, -- Auditar fallido	 		
			@procmsg	VARCHAR(8000)	, -- Mensaje devuelto por procedimientos llamados desde este procedimiento
			@procret 	BIT 			, -- Valor de retorno de los procedimientos llamados desde este procedimiento
			@idproce	int		    	, -- Codigo de proceso
	 		@retry 		BIT			    , -- 1=Reintentar ; 0=Abortar  
	 		@retrycont	INT			    , -- Contador de reintentos
	 		@maxretries INT			    , -- Maximo numero de reintentos
	 		@timeout	NVARCHAR(4000)  , -- Tiempo de espera maximo por bloqueo de registros
	 		@stmt 		NVARCHAR(4000)  , -- Cadena de instrucciones T-SQL
			@tc			INT 			, -- Numero de transacciones abiertas
			@msg	    VARCHAR(8000)   , -- Mensaje retornado por el sistema
			@retval		TINYINT 		, -- Valor de retorno de este procedimiento: 0:Exito ; 1:Error(Bloque Catch)
			@bl_tomarvendedorcliente BIT, -- Filtro para tomar vendedor del cliente /*rgelis 2014/12/18 - Toma el vendedor del cliente -EVT*/
			@bl_GenerarFacturaXTiquete BIT,
			@FiltrarSucursalFactAuto BIT;
	
	SELECT 	@idproce 			 = 123,
			@retry				 = 1 		   ,
			@retrycont			 = 0		   ,
			@tc 			 	 = @@TRANCOUNT ,
			@retval				 = 0;
  	
  	-- Manejo de tiempo de espera y de reintentos por bloqueo de tablas/registros  
   	SELECT @maxretries = 3
	SELECT @timeout    = 3000
	SET @stmt = N'SET LOCK_TIMEOUT '+ltrim(rtrim(@timeout))
	EXEC sp_executesql @stmt,N''
	
	
	WHILE ( (@retry = 1) AND (@retrycont <= @maxretries) )
	BEGIN
		SET @retry = 0;
    
    	-- Bloque TRY
    	BEGIN TRY 
    		
    	    		
    		--Obteniendo informacion de seguridad y auditoria--
			EXEC dbo.spzaProcesoUsuario_Consultar @id_usuario   = @id_usuario       ,
												  @id_proceso   = @idproce 		    , 
												  @bl_permit    = @bl_permit OUTPUT , 
												  @bl_auditsuc  = @bl_as 	 OUTPUT , 
												  @bl_auditfail = @bl_af 	 OUTPUT ;
			
			IF (@bl_permit = 0)
			BEGIN 
				
				SELECT 'No posee permisos suficientes para ejecutar esta acciÃ³n.' AS 'Respuesta'
				RETURN @retval;
			END 
			
	   
			--Instrucciones del procedimiento-----------------------------------------

			--CREATE TABLE #TablaReservas(Id INT IDENTITY,Id_ReservasGDS INT, id_ReservaGDS_Detalles INT, ds_ItinerarioAerolinea VARCHAR(128)) 
			DECLARE @MAXTablaReservas INT, @I INT, @Id_Reserva INT, @Id_ReservaGdsDetalle INT, @Result VARCHAR(128), @ItinerarioInicio VARCHAR(128), @ItinerarioFin VARCHAR(128), 
				@ItinerarioReserva VARCHAR(128), @ItinerarioTkt VARCHAR(128)
			DECLARE @TableItinerario  TABLE(Id INT IDENTITY, Itinerario VARCHAR(3), Itinerariofin VARCHAR(3)) 
			DECLARE @TableItinerarioFin TABLE(Id INT IDENTITY, Itinerario VARCHAR(3)) 
			SET @Result=''
			SET @FiltrarSucursalFactAuto = 0;
			SELECT @FiltrarSucursalFactAuto = CASE WHEN rtrim(ltrim(Valor))='S' THEN 1 ELSE 0 END  FROM dbo.Parametros where Id=426 /*JARG 2015/07/25 - filtrar por sucursal facturacion automatica -M&M*/
	
			--Obtenemos las reservas de detalle
			INSERT INTO #TablaReservas(Id_ReservasGDS, id_ReservaGDS_Detalles, ds_ItinerarioAerolinea)
			SELECT R.id,tkt.id,''
			FROM dbo.ReservasGDS As R
			INNER JOIN dbo.ReservasGDS_FacAuto fpa ON fpa.id_reserva = r.id
			INNER JOIN dbo.ReservaGDS_Detalles tkt ON tkt.id_reserva=R.id
			WHERE tkt.bl_usada = 0 AND (EXISTS (SELECT 1 FROM dbo.fnSplitMejorado(@cd_sucursal, ',', 0, 1) s WHERE s.Codigo = fpa.cd_sucursal) OR ISNULL(@cd_sucursal,'')='' OR @FiltrarSucursalFactAuto = 0)

			SELECT @MAXTablaReservas=COUNT(*),@I=1 FROM #TablaReservas

			WHILE @I <= @MAXTablaReservas 
			BEGIN
				--Obtenemos el Id de la reserva			
				SELECT @Id_Reserva = Id_ReservasGDS
						,@Id_ReservaGdsDetalle = id_ReservaGDS_Detalles	 
				FROM #TablaReservas WHERE id=@I
			
				--Obtenemos el itinerario del tkt
				SELECT
					@ItinerarioReserva = Case when ReservasGDS.iden_gds = 2 then ReservasGDS.ds_itinerario 
											  When isnull(ReservaGDS_Detalles.ds_itinerario,'') <> '' Then ReservaGDS_Detalles.ds_itinerario 
											  Else dbo.fnza_Get_ReservaItinerarioSobrante (ReservasGDS.Id,ReservaGDS_Detalles.Id) End
				FROM dbo.ReservasGDS
				INNER JOIN ReservaGDS_Detalles ON ReservaGDS_Detalles.id_reserva = ReservasGDS.id
				WHERE ReservaGDS_Detalles.id=@Id_ReservaGdsDetalle

				Set @ItinerarioTkt = @ItinerarioReserva

				SELECT @ItinerarioReserva=REPLACE(@ItinerarioReserva,'/ /','/')
				--llenamos las Variables que se usan como puente para el itinerario
				SELECT @ItinerarioInicio = LEFT(@ItinerarioReserva,LEN(@ItinerarioReserva)-4)
				SELECT @ItinerarioFin=RIGHT(@ItinerarioReserva,LEN(@ItinerarioReserva)-4)
			
				--Insetamos la parte inicial de los itinerarios
				DELETE FROM @TableItinerario

				DECLARE @Str VARCHAR(MAX), @Pos INT
				SET @Str = @ItinerarioInicio
				WHILE CHARINDEX('/', @Str) > 0
				BEGIN
					SET @Pos = CHARINDEX('/', @Str)
					INSERT INTO @TableItinerario (Itinerario) VALUES (LTRIM(RTRIM(LEFT(@Str, @Pos - 1))))
					SET @Str = SUBSTRING(@Str, @Pos + 1, LEN(@Str))
				END
				IF LEN(@Str) > 0
					INSERT INTO @TableItinerario (Itinerario) VALUES (LTRIM(RTRIM(@Str)))
			
				--Insetamos la parte Final de los itinerarios
				DELETE FROM @TableItinerarioFin
		
				SET @Str = @ItinerarioFin
				WHILE CHARINDEX('/', @Str) > 0
				BEGIN
					SET @Pos = CHARINDEX('/', @Str)
					INSERT INTO @TableItinerarioFin (itinerario) VALUES (LTRIM(RTRIM(LEFT(@Str, @Pos - 1))))
					SET @Str = SUBSTRING(@Str, @Pos + 1, LEN(@Str))
				END
				IF LEN(@Str) > 0
					INSERT INTO @TableItinerarioFin (itinerario) VALUES (LTRIM(RTRIM(@Str)))
			
				--Actualizamos para que quede armado el itinerario
				UPDATE t
				SET itinerariofin = t2.itinerario
				FROM @TableItinerario t
				INNER JOIN @TableItinerarioFin t2 ON t2.id = t.id
			
				--Obtenemos el itinerario por aerolinea cruzando con la ruta y reserva
				SET @Result=''

				Select @Result = @Result + cd_aero_siglas + '/' 
				FROM ReservaGDS_Itinerarios
				INNER JOIN @TableItinerario ti ON (ti.itinerario = cd_origen AND ti.itinerariofin = cd_destino)
				WHERE id_reserva = @Id_Reserva AND cd_aero_siglas IS NOT NULL 
		
				/*inicio rgelis 2013/09/13 sa cambia porque cuando pasa mas de 47 carateres se desborda en la factura de tiquetes*/
				--UPDATE #TablaReservas 
				--SET ds_ItinerarioAerolinea = LEFT(@Result,LEN(@Result)-1)
				--WHERE Id=@I
				UPDATE #TablaReservas 
				SET ds_ItinerarioAerolinea = CASE WHEN LEN(@Result)>47 THEN LEFT(@Result,47)
			 										WHEN LEN(@Result)>1 THEN LEFT(@Result,LEN(@Result)-1)
													ELSE @Result END
				WHERE Id=@I	AND LTRIM(ISNULL(@Result,''))<>''
				/*fin rgelis 2013/09/13 sa cambia porque cuando pasa mas de 47 carateres se desborda en la factura de tiquetes*/
			
				SET @I = @I + 1	
			END

			--Determinando si se debe auditar el proceso exitoso
			IF (@bl_as = 1) 
			BEGIN 										
				EXEC dbo.spzaAuditoria_Insertar  @id_proceso = @idproce    ,
												 @id_usuario = @id_usuario ,
												 @cd_status  = 1           , 												 
												 @admsg      = NULL        ,
							 					 @msgparams  = @msg;
			END 			 			
			
						
			RETURN @retval;
	    END TRY 
    																																			  
    	BEGIN CATCH 
    	-- Bloque CATCH (Manejo de excepciones)
 		
 			-- Tiempo de espera alcanzado --
		    IF ERROR_NUMBER() = 1222
		    BEGIN
      			SET @msg =  'No se pudo ejecutar el proceso. Tiempo de espera agotado.';
      			SET @retval = 1
	   	        RAISERROR (@msg,16,125);
	   	       	--Se debe auditar proceso fallido
				IF (@bl_af = 1) EXEC dbo.spzaAuditoria_Insertar  @id_proceso = @idproce ,
													 			 @id_usuario = @id_usuario ,
													 			 @cd_status  = 0           , 
													 			 @admsg      = @msg	   ;				
	   	        RETURN @retval;
		    END
		    
		    -- Registro bloqueado / Conflicto de actualizacion
		    ELSE IF ERROR_NUMBER() IN (1205, 3960)
    		BEGIN
	   	        
		       	SET @retry     = 1              ;
		       	SET @retrycont = @retrycont + 1 ; 

	    	 END
	    	 ELSE
		     BEGIN
		     	-- Error no manejado --
				IF (XACT_STATE() <> 0)
	   	        BEGIN 
														
					SET @retval = 1;
  	 				SET @msg =	'Ha ocurrido un error. InformaciÃ³n para soporte tecnico:'			+ CHAR(13)+ CHAR(10) + CHAR(13)+ CHAR(10) +
							    'Numero: ' + isnull(CAST(ERROR_NUMBER()   AS VARCHAR(10)),'') 		+ CHAR(13)+ CHAR(10) + CHAR(13)+ CHAR(10) +
								'Mensaje: ' + isnull(ERROR_MESSAGE(),'') 					   		+ CHAR(13)+ CHAR(10) + CHAR(13)+ CHAR(10) +
							 	'Severidad: ' + isnull(CAST(ERROR_SEVERITY() AS VARCHAR(10)),'') 	+ CHAR(13)+ CHAR(10) + CHAR(13)+ CHAR(10) +
							 	'Estado: ' + isnull(CAST(ERROR_STATE()    AS VARCHAR(10)),'') 		+ CHAR(13)+ CHAR(10) + CHAR(13)+ CHAR(10) +
								'Procedimiento: ' + isnull(ERROR_PROCEDURE(),'')					+ CHAR(13)+ CHAR(10) + CHAR(13)+ CHAR(10) +
								'Linea: ' + isnull(CAST(ERROR_LINE() 	   AS VARCHAR(10)),''); 							
		
					RAISERROR (@msg,16,126);
					--Se debe auditar proceso fallido
					IF (@bl_af = 1) EXEC dbo.spzaAuditoria_Insertar	@id_proceso = @idproce   ,
											 			 			@id_usuario = @id_usuario ,
											 			 			@cd_status  = 0           , 
											 			 			@admsg      = @msg	  ;				
					RETURN @retval;
	   	        END 
		     END
		END CATCH     
	END 
	
	IF (@retrycont>@maxretries) 
	BEGIN 
		SET @retval = 1
		SET @msg = 'No se pudo finalizar el proceso. Maximo numero de reintentos alcanzado.'
		--Se debe auditar proceso fallido
		IF (@bl_af = 1) EXEC dbo.spzaAuditoria_Insertar  @id_proceso = @idproce    ,
											 			 @id_usuario = @id_usuario ,
											 			 @cd_status  = 0           , 
											 			 @admsg      = @msg	   ;												 	   					   
  		RAISERROR (@msg,16,127);
  		RETURN @retval;
  	END   	
    
    RETURN @retval;
END
GO
