IF OBJECT_ID('dbo.spJOBFacturacionAuto', 'P') IS NOT NULL
    DROP PROCEDURE dbo.spJOBFacturacionAuto;
GO
SET QUOTED_IDENTIFIER ON;
GO

CREATE Procedure spJOBFacturacionAuto
	 
	As
Begin
	Set NoCount On

	Declare @Tiempo varchar(20)
	Declare @Horas varchar(20)
	Declare @Minutos varchar(20)
	Declare @Segundos varchar(20)
	Declare @TiempoN Int
	Declare @TiempoNAux Float
	Declare @Error Int
	

	Declare @Iden Int
	Declare @Categoria varchar(50)
	Declare @Operacion varchar(500)
	Declare @Llave1 varchar(50)
	Declare @Llave2 varchar(50)
	Declare @Llave3 varchar(50)
	Declare @Llave4 varchar(50)
	Declare @transaccion_guid uniqueidentifier
	Declare @Estado varchar(50)
	Declare @UltimoMensaje varchar(1000)
	Declare @Procesado datetime
	Declare @id_facture INT

	Declare @Fecha datetime
	Declare @FechaCont datetime
	Declare @Intentos Int
	Declare @Minute_wait INT

	Declare @MsjErrorValidar Varchar(MAX)
	Declare @Mensaje_Error Varchar(500);

	Declare @cur_cd_sucursal VARCHAR(MAX)
	Declare @cur_cd_implante VARCHAR(MAX)
	Declare @cur_id_sucursal INT
	Declare @cur_id_implante INT

	Declare @ReservaFactura VARCHAR(100)
	Declare @ds_cliid CHAR(10)
	Declare @cd_cliente CHAR(10)
	Declare @ds_cliname VARCHAR(250)
	Declare @ds_clidir VARCHAR(250)
	Declare @ds_clicity VARCHAR(50)
	Declare @ds_clitel VARCHAR(25)
	Declare @ds_ClienteEmail VARCHAR(100)
	Declare @ds_moneda CHAR(3)
	Declare @cd_vendedor CHAR(3)
	Declare @cd_tiqueteador VARCHAR(6)
	Declare @am_TasaCambio MONEY
	Declare @cd_tipoventa VARCHAR(10)
	Declare @cd_licitacion INT
	Declare @ds_descripcion VARCHAR(500)
	Declare @ds_Observaciones VARCHAR(8000)
	Declare @ds_archivo VARCHAR(250)
	Declare @id_reserva INT
	Declare @cd_reserva VARCHAR(10)
	Declare @cd_sucursal CHAR(5)
	Declare @cd_implante CHAR(5)
	Declare @id_sucursal INT
	Declare @id_implante INT
	Declare @cd_bu VARCHAR(25) 

	Declare @id_monedas_iata INT
	Declare @id_tiqueteador INT
	Declare @id_tipoventa INT
	Declare @am_tcambiousd MONEY
	Declare @ValorFactura MONEY

	Declare @ds_impas_iva VARCHAR(50)
	Declare @cd_impcta_iva VARCHAR(16)
	Declare @am_porcentaje_iva NUMERIC(5,2)

	-- Variables to fetch item fields inside the cursor of a specific invoice
	Declare @item_Tipo VARCHAR(4)
	Declare @item_id_reserva INT
	Declare @item_iden_gds INT
	Declare @item_ds_aero_code CHAR(3)
	Declare @item_ds_tkt_number CHAR(10)
	Declare @item_in_nacionalidad TINYINT
	Declare @item_am_tarifa MONEY
	Declare @item_am_iva MONEY
	Declare @item_am_tua MONEY
	Declare @item_am_comb MONEY
	Declare @item_am_vat MONEY
	Declare @item_am_Comision MONEY
	Declare @item_ds_pax_firstnm VARCHAR(30)
	Declare @item_ds_pax_lastnm VARCHAR(30)
	Declare @item_ds_pax_prefix CHAR(3)
	Declare @item_cd_tourcode VARCHAR(25)
	Declare @item_NumTktConj INT
	Declare @item_cd_TipoTiquete CHAR(3)
	Declare @item_id_air INT
	Declare @item_ds_itinerario VARCHAR(250)
	Declare @item_cd_Ahorro CHAR(3)
	Declare @item_am_highfare MONEY
	Declare @item_am_lowfare MONEY
	Declare @item_ds_solicita VARCHAR(200)
	Declare @item_ds_lapsoviaje VARCHAR(50)
	Declare @item_cd_tktrevisado VARCHAR(14)
	Declare @item_cd_PasaportePax VARCHAR(25)
	Declare @item_am_PorFacParcial MONEY
	Declare @item_in_cantpax INT
	Declare @item_Id_Precompra INT
	Declare @item_cd_FormaPagoTAO VARCHAR(3)
	Declare @item_TarjetaCreditoTAO VARCHAR(4)
	Declare @item_NumeroTarjetaTAO VARCHAR(25)
	Declare @item_am_fptao MONEY
	Declare @item_am_tao MONEY
	Declare @item_am_ivatao MONEY
	Declare @item_Id_Srv INT
	Declare @item_cd_conceptofacturacion INT
	Declare @item_cd_tiposervicio INT
	Declare @item_cd_proveedores VARCHAR(25)
	Declare @item_ds_proveedores VARCHAR(250)
	Declare @item_cd_confirmation VARCHAR(25)
	Declare @item_dt_checkin SMALLDATETIME
	Declare @item_dt_checkout SMALLDATETIME
	Declare @item_cd_city VARCHAR(25)
	Declare @item_in_noches INT
	Declare @item_Servicio VARCHAR(123)
	Declare @item_Descrip VARCHAR(78)
	Declare @item_am_TarifaContado MONEY
	Declare @item_am_IvaContado MONEY
	Declare @item_am_TarifaCredito MONEY
	Declare @item_am_IvaCredito MONEY
	Declare @item_cd_centrocosto VARCHAR(50)
	Declare @item_cd_auxiliar VARCHAR(50)
	Declare @item_cd_fp_OtrosItems VARCHAR(3)
	Declare @item_id_tipoproveedor INT
	Declare @item_cd_tipoproveedor VARCHAR(10)
	Declare @item_ds_tipoproveedor VARCHAR(100)
	Declare @item_Fecha_Salida SMALLDATETIME
	Declare @item_Fecha_Llegada SMALLDATETIME
	Declare @item_PNR VARCHAR(62)
	Declare @item_ds_itinerarioaerolinea VARCHAR(128)
	Declare @item_ds_tkt_prefix CHAR(3)
	Declare @item_bl_ahorro BIT
	Declare @item_cd_VencimientoTarjetaTAO CHAR(6)
	Declare @item_cd_NumeroPolizaTAO VARCHAR(50)
	Declare @item_cd_AnexoPolizaTAO VARCHAR(50)
	Declare @item_ds_AutorizacionTarjetaTAO VARCHAR(25)
	Declare @item_in_cuotasTarjetaTAO INT
	Declare @item_id_FormasPago INT
	Declare @item_id_TarjetasCredito INT
	Declare @item_am_fp1 MONEY
	Declare @item_ds_cc_code VARCHAR(2)
	Declare @item_ds_cc_number VARCHAR(25)
	Declare @item_ds_cc_vence VARCHAR(5)
	Declare @item_ds_cc_autorizacion VARCHAR(25)
	Declare @item_ds_cc_voucher VARCHAR(25)
	Declare @item_in_cc_cuotas INT
	Declare @item_am_fp2 MONEY
	Declare @item_ds_cc_code2 VARCHAR(2)
	Declare @item_ds_cc_number2 VARCHAR(25)
	Declare @item_ds_cc_vence2 VARCHAR(5)
	Declare @item_ds_cc_autorizacion2 VARCHAR(25)
	Declare @item_ds_cc_voucher2 VARCHAR(25)
	Declare @item_in_cc_cuotas2 INT
	Declare @item_cd_pax_CC VARCHAR(20)
	Declare @item_cd_destino VARCHAR(3)
	Declare @item_ds_clases VARCHAR(61)
	Declare @item_ds_Observaciones VARCHAR(8000)
	Declare @item_ds_fecha SMALLDATETIME
	Declare @SqlStmt NVARCHAR(MAX)

	Declare @ItemIndex INT
	Declare @ContadoRatio FLOAT
	Declare @TarifaSqlStmt NVARCHAR(MAX)
	Declare @TktSqlStmt NVARCHAR(MAX)
	Declare @TktItinSqlStmt NVARCHAR(MAX)
	Declare @TaoCargSqlStmt NVARCHAR(MAX)
	Declare @TaoFpSqlStmt NVARCHAR(MAX)
	Declare @TaoSqlStmt NVARCHAR(MAX)
	Declare @SrvCargSqlStmt NVARCHAR(MAX)
	Declare @SrvProvSqlStmt NVARCHAR(MAX)
	Declare @SrvPaxSqlStmt NVARCHAR(MAX)
	Declare @SrvHtlSqlStmt NVARCHAR(MAX)
	Declare @SrvImpuestosSqlStmt NVARCHAR(MAX)
	Declare @SrvFpSqlStmt NVARCHAR(MAX)
	Declare @SrvSqlStmt NVARCHAR(MAX)

	Declare @id_formaspago_tao INT
	Declare @ds_fpnm_tao VARCHAR(50)
	Declare @id_tarjetascredito_tao INT

	Declare @ResultTable TABLE (
		Respuesta VARCHAR(1000), 
		Estado INT,
		id_ReciboCaja INT,
		id_FormaPago INT,
		ds_FormaPago VARCHAR(100),
		cd_fuente VARCHAR(10),
		cd_serie VARCHAR(10),
		cd_consecutivo VARCHAR(20),
		ds_Tipo VARCHAR(50),
		am_valor MONEY,
		Resolucionmsg VARCHAR(1000),
		NCF VARCHAR(50),
		FechaCaducidad DATETIME,
		ds_Alerta VARCHAR(1000),
		in_ConsecutivoUnicoDocumento INT,
		DocumentoCausacionCxP VARCHAR(100)
	)
	Declare @FacturaRespuesta VARCHAR(MAX)
	Declare @FacturaEstado INT

	-- Variables for #GenerarConceptosAuto cursor loop
	Declare @c_id_ConceptoFacturacion INT
	Declare @c_cd_ConceptoFacturacion VARCHAR(50)
	Declare @c_ds_ConceptoFacturacion VARCHAR(250)
	Declare @c_id_TiposConceptFac INT
	Declare @c_bl_contorlarCargImp BIT
	Declare @c_bl_CalculoAutoValoresFacturacion BIT
	Declare @c_id_TiposServicio INT
	Declare @c_cd_TiposServicio VARCHAR(50)
	Declare @c_ds_TiposServicio VARCHAR(250)
	Declare @c_cd_proveedores VARCHAR(25)
	Declare @c_ds_proveedores VARCHAR(250)
	Declare @c_cd_tiquete VARCHAR(50)
	Declare @c_ds_servicio VARCHAR(250)
	Declare @c_ds_descrip VARCHAR(500)
	Declare @c_ds_paxname VARCHAR(30)
	Declare @c_ds_paxape VARCHAR(30)
	Declare @c_cd_paxtype CHAR(3)
	Declare @c_ds_paxClasificacion CHAR(6)
	Declare @c_in_nacionalidad TINYINT
	Declare @c_dt_llegada SMALLDATETIME
	Declare @c_dt_salida SMALLDATETIME
	Declare @c_cd_cencosto VARCHAR(50)
	Declare @c_cd_auxiliar VARCHAR(50)
	Declare @c_cd_item VARCHAR(50)
	Declare @c_Valor MONEY
	Declare @c_am_Contado MONEY
	Declare @c_am_Credito MONEY
	Declare @c_ValorIva MONEY
	Declare @c_Total MONEY
	Declare @c_PorIva NUMERIC(5,2)
	Declare @c_am_ContadoIva MONEY
	Declare @c_am_CreditoIva MONEY
	Declare @c_codigoimpiva VARCHAR(3)
	Declare @c_nombreimpiva VARCHAR(50) 
	Declare @c_ColId VARCHAR(25)
	Declare @c_cd_Consecutivo_depende VARCHAR(50)
	Declare @c_CodigoReserva VARCHAR(50)
	Declare @c_am_ImpuestoComision MONEY
	Declare @c_Respuesta VARCHAR(1000)
	Declare @c_bl_RutaExentaIva BIT
	Declare @c_id_FormasPago INT
	Declare @c_id_TarjetasCredito INT
	Declare @c_am_basedescuento MONEY
	Declare @c_am_pordescuento NUMERIC(8,4)
	Declare @c_id_FormasPagoAirPlus INT
	Declare @c_cd_FormasPagoAirPlus VARCHAR(3)
	Declare @c_ds_FormasPagoAirPlus VARCHAR(100)
	Declare @c_id_TarjetasCreditoAirPlus INT
	Declare @c_cd_TarjetasCreditoAirPlus VARCHAR(4)
	Declare @c_ds_numerotarjetaAirPlus VARCHAR(25)
	Declare @c_cd_codigotc VARCHAR(2)
	Declare @c_ds_numerotc VARCHAR(25)
	Declare @c_ds_vencetc VARCHAR(5)
	Declare @c_ds_autorizaciontc VARCHAR(25)
	Declare @c_ds_vouchertc VARCHAR(25)
	Declare @c_in_cuotastc INT


	DECLARE @CalcularAutoValoresItemFac CHAR(1) = 'N';
	DECLARE @RecalcTotalValue MONEY;
	DECLARE @RecalcTotalPayment MONEY;
	DECLARE @NumDecimales INT

	-- Habilitar envÃƒÂ­o de facturaciÃƒÂ³n automatica
	If Not Exists(Select * From Parametros Where Id=900 And Valor= 'S')
	Begin
		WaitFor Delay '23:59:00'
		Return
	End

	-- Fetch tax details for standard IVA (id=1)
	SELECT TOP 1 
		@ds_impas_iva = ds_nombre, 
		@cd_impcta_iva = cd_cuenta, 
		@am_porcentaje_iva = am_porcentaje,
		@c_PorIva = am_porcentaje,
		@c_codigoimpiva = cd_codigo,
		@c_nombreimpiva = ds_nombre
	FROM dbo.ImpRet 
	WHERE id = 1;

	SELECT @NumDecimales = CONVERT(INT,LTRIM(RTRIM(valor))) from dbo.parametros where id = 33;
	IF @NumDecimales IS NULL SET @NumDecimales = 2;

	SELECT @CalcularAutoValoresItemFac = ISNULL(LTRIM(RTRIM(valor)), 'N') FROM dbo.Parametros WHERE id = 326;

	
	
	-- Tiempo de espera
	Select @Tiempo = CONVERT(INT,LTRIM(RTRIM(valor))) From Parametros Where Id=901
	If IsNumeric(@Tiempo) = 1
	Begin
		Set @TiempoNAux = @Tiempo
		Set @TiempoNAux = Round(@TiempoNAux, 0)
		If @TiempoNAux > 86399 Set @TiempoNAux = 86399
		Set @TiempoN = @TiempoNAux
	End
	Else
	Begin
		Set @TiempoN = 5 
	End

	Set @Segundos = cast(@TiempoN % 60 As varchar(20))
	Set @TiempoN = @TiempoN / 60
	Set @Minutos = cast(@TiempoN % 60 As varchar(20))
	Set @TiempoN = @TiempoN / 60
	Set @Horas = cast(@TiempoN % 24 As varchar(20))
	Set @Tiempo = @Horas + ':' + @Minutos + ':' + @Segundos

	-- Create the temp table to store the query result of spza_GDSFacturacionAuto_Consultar
	CREATE TABLE #GDSFacturacionAuto (
		PNR VARCHAR(62) COLLATE DATABASE_DEFAULT,
		Tipo VARCHAR(4) COLLATE DATABASE_DEFAULT,
		Servicio VARCHAR(123) COLLATE DATABASE_DEFAULT,
		Descrip VARCHAR(78) COLLATE DATABASE_DEFAULT,
		id INT,
		iden_gds INT,
		ds_fecha SMALLDATETIME,
		cd_tiqueteador VARCHAR(6) COLLATE DATABASE_DEFAULT,
		cd_vendedor CHAR(3) COLLATE DATABASE_DEFAULT,
		cd_cliente CHAR(10) COLLATE DATABASE_DEFAULT,
		am_highfare MONEY,
		am_lowfare MONEY,
		am_fare MONEY,
		ds_reasoncode CHAR(2) COLLATE DATABASE_DEFAULT,
		ds_cliname VARCHAR(250) COLLATE DATABASE_DEFAULT,
		ds_clidir VARCHAR(250) COLLATE DATABASE_DEFAULT,
		ds_clicity VARCHAR(50) COLLATE DATABASE_DEFAULT,
		ds_cliid CHAR(10) COLLATE DATABASE_DEFAULT,
		ds_itinerario VARCHAR(250) COLLATE DATABASE_DEFAULT,
		ds_clases VARCHAR(61) COLLATE DATABASE_DEFAULT,
		in_nacionalidad TINYINT,
		id_air INT,
		ds_pax_number TINYINT,
		ds_pax_firstnm VARCHAR(30) COLLATE DATABASE_DEFAULT,
		ds_pax_lastnm VARCHAR(30) COLLATE DATABASE_DEFAULT,
		ds_pax_prefix CHAR(3) COLLATE DATABASE_DEFAULT,
		ds_tkt_number CHAR(10) COLLATE DATABASE_DEFAULT,
		ds_tkt_prefix CHAR(3) COLLATE DATABASE_DEFAULT,
		ds_aero_code CHAR(3) COLLATE DATABASE_DEFAULT,
		ds_moneda CHAR(3) COLLATE DATABASE_DEFAULT,
		am_tarifa MONEY,
		am_iva MONEY,
		am_tua MONEY,
		am_comb MONEY,
		am_vat MONEY,
		ds_cc_code CHAR(2) COLLATE DATABASE_DEFAULT,
		ds_cc_number VARCHAR(25) COLLATE DATABASE_DEFAULT,
		am_tao MONEY,
		am_ivatao MONEY,
		am_cap MONEY,
		am_ivacap MONEY,
		ds_cc_code2 CHAR(2) COLLATE DATABASE_DEFAULT,
		ds_cc_number2 CHAR(16) COLLATE DATABASE_DEFAULT,
		am_fp1 MONEY,
		am_fp2 MONEY,
		cd_tktrevisado VARCHAR(14) COLLATE DATABASE_DEFAULT,
		am_TarifaContado MONEY,
		am_IvaContado MONEY,
		am_OtrosContado MONEY,
		am_TarifaCredito MONEY,
		am_IvaCredito MONEY,
		am_OtrosCredito MONEY,
		am_Comision MONEY,
		cd_clitipodoc VARCHAR(100) COLLATE DATABASE_DEFAULT,
		cd_clitipotercero CHAR(1) COLLATE DATABASE_DEFAULT,
		ds_clirazoncial VARCHAR(250) COLLATE DATABASE_DEFAULT,
		ds_cliname2 VARCHAR(60) COLLATE DATABASE_DEFAULT,
		ds_clilastname VARCHAR(60) COLLATE DATABASE_DEFAULT,
		ds_clilastname2 VARCHAR(60) COLLATE DATABASE_DEFAULT,
		cd_clipais VARCHAR(25) COLLATE DATABASE_DEFAULT,
		ds_clitel VARCHAR(25) COLLATE DATABASE_DEFAULT,
		cd_TipoTransaccion VARCHAR(1) COLLATE DATABASE_DEFAULT,
		Fecha_Salida SMALLDATETIME,
		Fecha_Llegada SMALLDATETIME,
		Id_Srv INT,
		cd_conceptofacturacion INT,
		cd_tiposervicio INT,
		cd_proveedores VARCHAR(25) COLLATE DATABASE_DEFAULT,
		ds_proveedores VARCHAR(250) COLLATE DATABASE_DEFAULT,
		id_car INT,
		dt_entrega SMALLDATETIME,
		in_cars INT,
		cd_carcode VARCHAR(25) COLLATE DATABASE_DEFAULT,
		cd_conf_car VARCHAR(25) COLLATE DATABASE_DEFAULT,
		cd_citysalida VARCHAR(25) COLLATE DATABASE_DEFAULT,
		dt_retorno SMALLDATETIME,
		cd_cartype VARCHAR(25) COLLATE DATABASE_DEFAULT,
		cd_currency VARCHAR(10) COLLATE DATABASE_DEFAULT,
		am_tarifacar MONEY,
		cd_bookingsource VARCHAR(25) COLLATE DATABASE_DEFAULT,
		cd_ratecode VARCHAR(25) COLLATE DATABASE_DEFAULT,
		id_htl INT,
		dt_checkin SMALLDATETIME,
		in_guests INT,
		cd_confirmation VARCHAR(25) COLLATE DATABASE_DEFAULT,
		cd_city VARCHAR(25) COLLATE DATABASE_DEFAULT,
		cd_htlchain VARCHAR(25) COLLATE DATABASE_DEFAULT,
		dt_checkout SMALLDATETIME,
		in_noches INT,
		ds_htlname VARCHAR(250) COLLATE DATABASE_DEFAULT,
		in_habs INT,
		cd_bed VARCHAR(25) COLLATE DATABASE_DEFAULT,
		cd_ratecode_htl VARCHAR(25) COLLATE DATABASE_DEFAULT,
		cd_htlcur VARCHAR(10) COLLATE DATABASE_DEFAULT,
		am_htltarifa MONEY,
		cd_agcur VARCHAR(10) COLLATE DATABASE_DEFAULT,
		am_agtarifa MONEY,
		ds_dir1 VARCHAR(250) COLLATE DATABASE_DEFAULT,
		ds_tel VARCHAR(25) COLLATE DATABASE_DEFAULT,
		ds_fax VARCHAR(25) COLLATE DATABASE_DEFAULT,
		cd_centrocosto VARCHAR(50) COLLATE DATABASE_DEFAULT,
		NumTktConj INT,
		Respuesta VARCHAR(1) COLLATE DATABASE_DEFAULT,
		ds_solicita VARCHAR(200) COLLATE DATABASE_DEFAULT,
		cd_pax_CC VARCHAR(20) COLLATE DATABASE_DEFAULT,
		ds_lapsoviaje VARCHAR(50) COLLATE DATABASE_DEFAULT,
		ds_archivo VARCHAR(250) COLLATE DATABASE_DEFAULT,
		ds_Observaciones VARCHAR(8000) COLLATE DATABASE_DEFAULT,
		ds_ClienteEmail VARCHAR(100) COLLATE DATABASE_DEFAULT,
		cd_sucursal CHAR(5) COLLATE DATABASE_DEFAULT,
		cd_implante CHAR(5) COLLATE DATABASE_DEFAULT,
		bl_ClienteActualizar BIT,
		bl_NotificacionMPD BIT,
		cd_FormaPagoTAO VARCHAR(3) COLLATE DATABASE_DEFAULT,
		cd_TarjetaCreditoTAO VARCHAR(4) COLLATE DATABASE_DEFAULT,
		cd_NumeroTarjetaTAO VARCHAR(25) COLLATE DATABASE_DEFAULT,
		cd_VencimientoTarjetaTAO CHAR(6) COLLATE DATABASE_DEFAULT,
		cd_NumeroPolizaTAO VARCHAR(50) COLLATE DATABASE_DEFAULT,
		cd_AnexoPolizaTAO VARCHAR(50) COLLATE DATABASE_DEFAULT,
		am_PorDesFormaPagoTA NUMERIC(8,4),
		cd_Penalidad CHAR(14) COLLATE DATABASE_DEFAULT,
		ds_cc_vence CHAR(5) COLLATE DATABASE_DEFAULT,
		ds_cc_vence2 CHAR(5) COLLATE DATABASE_DEFAULT,
		ds_cc_autorizacion VARCHAR(25) COLLATE DATABASE_DEFAULT,
		ds_cc_autorizacion2 VARCHAR(25) COLLATE DATABASE_DEFAULT,
		ds_cc_voucher VARCHAR(25) COLLATE DATABASE_DEFAULT,
		ds_cc_voucher2 VARCHAR(10) COLLATE DATABASE_DEFAULT,
		ds_AutorizacionTarjetaTAO VARCHAR(25) COLLATE DATABASE_DEFAULT,
		ds_VoucherTarjetaTAO VARCHAR(25) COLLATE DATABASE_DEFAULT,
		am_fptao MONEY,
		in_cc_cuotas INT,
		in_cc_cuotas2 INT,
		in_cuotasTarjetaTAO INT,
		cd_TipoTarifaTAO VARCHAR(25) COLLATE DATABASE_DEFAULT,
		cd_TipoTiquete CHAR(3) COLLATE DATABASE_DEFAULT,
		am_TasaCambio MONEY,
		cd_tiqueteador_facturador CHAR(3) COLLATE DATABASE_DEFAULT,
		bl_ahorro BIT,
		in_CantidadTarifaTAO INT,
		in_CantidadSegmentoTAO INT,
		cd_tourcode VARCHAR(25) COLLATE DATABASE_DEFAULT,
		ds_contrato VARCHAR(25) COLLATE DATABASE_DEFAULT,
		cd_PasaportePax VARCHAR(25) COLLATE DATABASE_DEFAULT,
		ds_itinerarioaerolinea VARCHAR(128) COLLATE DATABASE_DEFAULT,
		ds_tkt_prefixIata CHAR(3) COLLATE DATABASE_DEFAULT,
		ds_Evento VARCHAR(250) COLLATE DATABASE_DEFAULT,
		cd_iata VARCHAR(25) COLLATE DATABASE_DEFAULT,
		ds_aero_codeIata CHAR(3) COLLATE DATABASE_DEFAULT,
		ReservaFactura VARCHAR(100) COLLATE DATABASE_DEFAULT,
		cd_Ahorro CHAR(3) COLLATE DATABASE_DEFAULT,
		cd_Categoria VARCHAR(50) COLLATE DATABASE_DEFAULT,
		Id_FormasPagoAirPlus INT,
		cd_FormasPagoAirPlus VARCHAR(3) COLLATE DATABASE_DEFAULT,
		ds_FormasPagoAirPlus VARCHAR(100) COLLATE DATABASE_DEFAULT,
		cd_TarjetasCreditoAirPlus VARCHAR(4) COLLATE DATABASE_DEFAULT,
		ds_numerotarjetaAirPlus VARCHAR(25) COLLATE DATABASE_DEFAULT,
		am_PorFacParcial MONEY,
		am_PorFacParcial_Utilizar MONEY,
		in_cantpax INT,
		Id_Precompra INT,
		id_sucursal INT,
		bl_cotizacion BIT,
		cd_htl VARCHAR(50) COLLATE DATABASE_DEFAULT,
		id_FormasPago INT,
		id_TarjetasCredito INT,
		id_formapago_cliente INT,
		cd_formapago_cliente VARCHAR(3) COLLATE DATABASE_DEFAULT,
		ds_formapago_cliente VARCHAR(100) COLLATE DATABASE_DEFAULT,
		cd_fp_OtrosItems VARCHAR(3) COLLATE DATABASE_DEFAULT,
		cd_auxiliar VARCHAR(50) COLLATE DATABASE_DEFAULT,
		cd_tipoventa VARCHAR(10) COLLATE DATABASE_DEFAULT,
		am_iva2 MONEY,
		cd_licitacion INT,
		ds_descripcion VARCHAR(500) COLLATE DATABASE_DEFAULT,
		id_tipoproveedor INT,
		cd_tipoproveedor VARCHAR(10) COLLATE DATABASE_DEFAULT,
		ds_tipoproveedor VARCHAR(100) COLLATE DATABASE_DEFAULT,
		cd_Consecutivo_variablesadicionales VARCHAR(50) COLLATE DATABASE_DEFAULT
	);

	CREATE TABLE #CargosImpuestosJob (
		id INT, id_reserva INT, id_reservaGDS_detalles INT, id_reservaGDS_servicios INT,
		in_orden INT, cd_codigo VARCHAR(20) COLLATE DATABASE_DEFAULT, ds_nombre VARCHAR(100) COLLATE DATABASE_DEFAULT, cd_tipo CHAR(1) COLLATE DATABASE_DEFAULT, 
		cd_codigopadre VARCHAR(20) COLLATE DATABASE_DEFAULT, cd_tipopadre VARCHAR(20) COLLATE DATABASE_DEFAULT, am_porcentaje NUMERIC(8,4),
		am_contado MONEY, am_credito MONEY, am_valor MONEY
	);

	CREATE TABLE #FormasPagosJob (
		id INT, id_reserva INT, id_reservaGDS_detalles INT, id_reservaGDS_servicios INT,
		in_orden INT, id_formaspago INT, cd_codigo VARCHAR(10) COLLATE DATABASE_DEFAULT, ds_nombre VARCHAR(50) COLLATE DATABASE_DEFAULT,
		id_tarjetascredito INT, cd_tipotarjeta VARCHAR(10) COLLATE DATABASE_DEFAULT, ds_numerotarjeta VARCHAR(50) COLLATE DATABASE_DEFAULT,
		ds_vouchertarjeta VARCHAR(50) COLLATE DATABASE_DEFAULT, ds_expiraciontarjeta VARCHAR(10) COLLATE DATABASE_DEFAULT, ds_autorizaciontarjeta VARCHAR(50) COLLATE DATABASE_DEFAULT,
		in_coutas INT, cd_banco VARCHAR(50) COLLATE DATABASE_DEFAULT, ds_cheque VARCHAR(50) COLLATE DATABASE_DEFAULT, ds_plaza VARCHAR(50) COLLATE DATABASE_DEFAULT,
		ds_referencia VARCHAR(50) COLLATE DATABASE_DEFAULT, ds_Poliza VARCHAR(50) COLLATE DATABASE_DEFAULT, ds_PolizaAnexo VARCHAR(50) COLLATE DATABASE_DEFAULT, am_valor MONEY
	);

	CREATE TABLE #GenerarConceptosAuto (
		id_ConceptoFacturacion INT,
		cd_ConceptoFacturacion VARCHAR(50) COLLATE DATABASE_DEFAULT,
		ds_ConceptoFacturacion VARCHAR(250) COLLATE DATABASE_DEFAULT,
		id_TiposConceptFac INT,
		bl_contorlarCargImp BIT,
		bl_CalculoAutoValoresFacturacion BIT,
		id_TiposServicio INT,
		cd_TiposServicio VARCHAR(50) COLLATE DATABASE_DEFAULT,
		ds_TiposServicio VARCHAR(250) COLLATE DATABASE_DEFAULT,
		cd_proveedores VARCHAR(25) COLLATE DATABASE_DEFAULT,
		ds_proveedores VARCHAR(250) COLLATE DATABASE_DEFAULT,
		cd_tiquete VARCHAR(50) COLLATE DATABASE_DEFAULT,
		ds_servicio VARCHAR(250) COLLATE DATABASE_DEFAULT,
		ds_descrip VARCHAR(500) COLLATE DATABASE_DEFAULT,
		ds_paxname VARCHAR(30) COLLATE DATABASE_DEFAULT,
		ds_paxape VARCHAR(30) COLLATE DATABASE_DEFAULT,
		cd_paxtype CHAR(3) COLLATE DATABASE_DEFAULT,
		ds_paxClasificacion CHAR(6) COLLATE DATABASE_DEFAULT,
		in_nacionalidad TINYINT,
		dt_llegada SMALLDATETIME,
		dt_salida SMALLDATETIME,
		cd_cencosto VARCHAR(50) COLLATE DATABASE_DEFAULT,
		cd_auxiliar VARCHAR(50) COLLATE DATABASE_DEFAULT,
		cd_item VARCHAR(50) COLLATE DATABASE_DEFAULT,
		Valor MONEY,
		am_Contado MONEY,
		am_Credito MONEY,
		ColId VARCHAR(25) COLLATE DATABASE_DEFAULT,
		cd_Consecutivo_depende VARCHAR(50) COLLATE DATABASE_DEFAULT,
		CodigoReserva VARCHAR(50) COLLATE DATABASE_DEFAULT,
		am_ImpuestoComision MONEY,
		Respuesta VARCHAR(1000) COLLATE DATABASE_DEFAULT,
		bl_RutaExentaIva BIT,
		id_FormasPago INT,
		id_TarjetasCredito INT,
		am_basedescuento MONEY,
		am_pordescuento NUMERIC(8,4),
		id_FormasPagoAirPlus INT,
		cd_FormasPagoAirPlus VARCHAR(3) COLLATE DATABASE_DEFAULT,
		ds_FormasPagoAirPlus VARCHAR(100) COLLATE DATABASE_DEFAULT,
		id_TarjetasCreditoAirPlus INT,
		cd_TarjetasCreditoAirPlus VARCHAR(4) COLLATE DATABASE_DEFAULT,
		ds_numerotarjetaAirPlus VARCHAR(25) COLLATE DATABASE_DEFAULT,
		cd_codigotc VARCHAR(2) COLLATE DATABASE_DEFAULT,
		ds_numerotc VARCHAR(25) COLLATE DATABASE_DEFAULT,
		ds_vencetc VARCHAR(5) COLLATE DATABASE_DEFAULT,
		ds_autorizaciontc VARCHAR(25) COLLATE DATABASE_DEFAULT,
		ds_vouchertc VARCHAR(25) COLLATE DATABASE_DEFAULT,
		in_cuotastc INT
	);

	CREATE TABLE #TmpFacturaItems (
		id_item INT IDENTITY(1,1) PRIMARY KEY,
		tipo_item VARCHAR(10),                 -- 'TKT', 'TAO', 'SRV'
		id_referencia_origen INT,              -- ID de ReservasGDS_Detalles or ReservaGDS_Servicios
		cd_tiquete VARCHAR(50),
		ds_descrip VARCHAR(500),
		in_nacionalidad INT,
		cd_cencosto VARCHAR(50),
		cd_auxiliar VARCHAR(50),
		cd_item VARCHAR(50),
		am_tarifa MONEY,
		am_iva MONEY,
		am_tua MONEY,
		am_comb MONEY,
		am_vat MONEY,
		am_Comision MONEY,
		ds_paxname VARCHAR(30),
		ds_paxape VARCHAR(30),
		ds_paxprefix CHAR(3),
		cd_tourcode VARCHAR(25),
		NumTktConj INT,
		cd_TipoTiquete CHAR(3),
		id_air INT,
		ds_itinerario VARCHAR(250),
		ds_itinerarioaerolinea VARCHAR(128),
		ds_clases VARCHAR(61),
		ds_Observaciones VARCHAR(8000),
		am_highfare MONEY,
		am_lowfare MONEY,
		ds_solicita VARCHAR(200),
		ds_lapsoviaje VARCHAR(50),
		cd_tktrevisado VARCHAR(14),
		cd_PasaportePax VARCHAR(25),
		cd_pax_CC VARCHAR(20),
		am_PorFacParcial MONEY,
		in_cantpax INT,
		Id_Precompra INT,
		cd_FormaPagoTAO VARCHAR(3),
		cd_TarjetaCreditoTAO VARCHAR(4),
		cd_NumeroTarjetaTAO VARCHAR(25),
		cd_VencimientoTarjetaTAO CHAR(6),
		cd_NumeroPolizaTAO VARCHAR(50),
		cd_AnexoPolizaTAO VARCHAR(50),
		ds_AutorizacionTarjetaTAO VARCHAR(25),
		in_cuotasTarjetaTAO INT,
		id_FormasPago INT,
		id_TarjetasCredito INT,
		am_fp1 MONEY,
		ds_cc_code VARCHAR(2),
		ds_cc_number VARCHAR(25),
		ds_cc_vence VARCHAR(5),
		ds_cc_autorizacion VARCHAR(25),
		ds_cc_voucher VARCHAR(25),
		in_cc_cuotas INT,
		am_fp2 MONEY,
		ds_cc_code2 VARCHAR(2),
		ds_cc_number2 VARCHAR(25),
		ds_cc_vence2 VARCHAR(5),
		ds_cc_autorizacion2 VARCHAR(25),
		ds_cc_voucher2 VARCHAR(25),
		in_cc_cuotas2 INT,
		id_monedas_iata INT,
		Tcambio MONEY,
		id_sucursal INT,
		id_implante INT,
		bl_ahorro BIT,
		cd_TipoTiqueteGDS VARCHAR(3),
		id_TiposDocumento INT,
		id_entdist INT,
		id_entvend INT,
		cd_destino VARCHAR(3),
		dt_fechaexped SMALLDATETIME,
		id_tiqueteadores INT,
		id_gds INT,
		iden_gds INT,
		am_comisionPNR MONEY,
		ds_records VARCHAR(62),
		bl_NoCalcComision BIT,
		bl_NoCalcIvaComision BIT,
		am_basecomisionable MONEY,
		am_porcomision MONEY,
		id_tiposconceptfac INT,
		id_conceptofacturacion INT,
		id_tiposservicio INT,
		cd_proveedores VARCHAR(25),
		ds_servicio VARCHAR(250),
		am_valorprov MONEY,
		id_monedaprov INT,
		dt_llegada SMALLDATETIME,
		dt_salida SMALLDATETIME,
		am_pordescuento NUMERIC(8,4),
		am_basedescuento MONEY,
		Fecha_Salida SMALLDATETIME,
		Fecha_Llegada SMALLDATETIME,
		ColId VARCHAR(25),
		cd_Consecutivo_depende VARCHAR(50),
		CodigoReserva VARCHAR(50),
		cd_Consecutivo_variablesadicionales VARCHAR(50),
		am_valor_total MONEY,
		ds_proveedores VARCHAR(250) COLLATE DATABASE_DEFAULT,
		id_FormasPagoAirPlus INT,
		cd_FormasPagoAirPlus VARCHAR(3) COLLATE DATABASE_DEFAULT,
		ds_FormasPagoAirPlus VARCHAR(100) COLLATE DATABASE_DEFAULT,
		id_TarjetasCreditoAirPlus INT,
		cd_TarjetasCreditoAirPlus VARCHAR(4) COLLATE DATABASE_DEFAULT,
		ds_numerotarjetaAirPlus VARCHAR(25) COLLATE DATABASE_DEFAULT,
		id_reserva INT,
		OrdenGrabacion INT
	);

	CREATE TABLE #TmpFacturaCargos (
		id_cargo_temp INT IDENTITY(1,1) PRIMARY KEY,
		id_item INT,
		cd_codigo VARCHAR(20) COLLATE DATABASE_DEFAULT,
		ds_nombre VARCHAR(100) COLLATE DATABASE_DEFAULT,
		cd_tipo CHAR(1) COLLATE DATABASE_DEFAULT,
		am_porcentaje NUMERIC(8,4),
		am_valor MONEY,
		am_contado MONEY,
		am_credito MONEY,
		id_carg INT,
		id_imp INT,
		bl_iva BIT,
		in_orden INT
	);

	CREATE TABLE #TmpFacturaFormasPago (
		id_fp_temp INT IDENTITY(1,1) PRIMARY KEY,
		id_item INT,
		id_formaspago INT,
		cd_codigo VARCHAR(10) COLLATE DATABASE_DEFAULT,
		ds_nombre VARCHAR(50) COLLATE DATABASE_DEFAULT,
		id_tarjetascredito INT,
		cd_tipotarjeta VARCHAR(10) COLLATE DATABASE_DEFAULT,
		ds_numerotarjeta VARCHAR(50) COLLATE DATABASE_DEFAULT,
		ds_vouchertarjeta VARCHAR(50) COLLATE DATABASE_DEFAULT,
		ds_expiraciontarjeta VARCHAR(10) COLLATE DATABASE_DEFAULT,
		ds_autorizaciontarjeta VARCHAR(50) COLLATE DATABASE_DEFAULT,
		in_cuotas INT,
		cd_banco VARCHAR(50) COLLATE DATABASE_DEFAULT,
		ds_cheque VARCHAR(50) COLLATE DATABASE_DEFAULT,
		ds_plaza VARCHAR(50) COLLATE DATABASE_DEFAULT,
		ds_referencia VARCHAR(50) COLLATE DATABASE_DEFAULT,
		ds_Poliza VARCHAR(50) COLLATE DATABASE_DEFAULT,
		ds_PolizaAnexo VARCHAR(50) COLLATE DATABASE_DEFAULT,
		am_valor MONEY
	);

	While 1 = 1
	Begin
		SET @Fecha = GETDATE();
		SELECT @FechaCont=REPLACE(VALOPAR,'/','') FROM dbo.Parametr WHERE PARAMETRO = 'FECHACT'
		-- Cursor over unique combinations of sucursal/implante in queue
		--DECLARE curConfigs CURSOR LOCAL FOR
		---SELECT DISTINCT cd_sucursal, ISNULL(cd_implante, '0')
		--FROM dbo.ReservasGDS_FacAuto;

		SELECT  @cur_cd_sucursal = LTRIM(RTRIM(valor)) from dbo.parametros where id = 902;
		SELECT  @cur_cd_implante = LTRIM(RTRIM(valor)) from dbo.parametros where id = 903;

		-- Clear and fill temporary table for all configured combinations at once
		DELETE FROM #GDSFacturacionAuto;
		
		INSERT INTO #GDSFacturacionAuto
		EXEC dbo.spza_GDSFacturacionAutoJOB_Consultar 
			@id_usuario = 1, 
			@cd_sucursal = @cur_cd_sucursal, 
			@cd_implante = @cur_cd_implante;

			-- Cursor over unique ReservaFactura in this query result
			DECLARE curInvoices CURSOR LOCAL FOR
			SELECT DISTINCT ReservaFactura
			FROM #GDSFacturacionAuto;

			OPEN curInvoices;
			FETCH NEXT FROM curInvoices INTO @ReservaFactura;

			WHILE @@FETCH_STATUS = 0
			BEGIN
				DELETE FROM #TmpFacturaItems;
				DELETE FROM #TmpFacturaCargos;
				DELETE FROM #TmpFacturaFormasPago;

				-- Fetch header details from the first record in the group

				SELECT TOP 1
					@ds_cliid = ds_cliid,
					@cd_cliente = cd_cliente,
					@ds_cliname = ds_cliname,
					@ds_clidir = ds_clidir,
					@ds_clicity = ds_clicity,
					@ds_clitel = ds_clitel,
					@ds_ClienteEmail = ds_ClienteEmail,
					@ds_moneda = ds_moneda,
					@cd_vendedor = cd_vendedor,
					@cd_tiqueteador = cd_tiqueteador,
					@am_TasaCambio = am_TasaCambio,
					@cd_tipoventa = cd_tipoventa,
					@cd_licitacion = cd_licitacion,
					@ds_descripcion = ds_descripcion,
					@ds_Observaciones = ds_Observaciones,
					@ds_archivo = ds_archivo,
					@id_reserva = id,
					@cd_reserva = PNR,
					@cd_sucursal = cd_sucursal,
					@cd_implante = cd_implante
				FROM #GDSFacturacionAuto
				WHERE ReservaFactura = @ReservaFactura;

				-- Resolve IDs for headers
				IF ISNULL(@cd_sucursal,'')=''
				BEGIN
					SET @cd_sucursal='OFP'
					SET @cd_implante=NULL
				END
				SELECT @id_sucursal = id FROM dbo.Sucursales WHERE cd_codigo = @cd_sucursal;
				SELECT @id_implante = id FROM dbo.Implantes WHERE cd_codigo = @cd_implante AND id_sucursal = @id_sucursal;
				SELECT @id_monedas_iata = id FROM dbo.Monedas_IATA WHERE cd_codigo = @ds_moneda;
				SELECT @id_tiqueteador = id FROM dbo.Tiqueteadores WHERE cd_codigo = @cd_tiqueteador;
				SELECT @id_tipoventa = id_tipoventa FROM dbo.Tiqueteadores WHERE cd_codigo = @cd_tiqueteador;
				SELECT @cd_bu = cd_bu FROM dbo.Implantes WHERE cd_codigo = @cd_implante AND id_sucursal = @id_sucursal;
				SELECT @cd_bu = cd_bu FROM dbo.Sucursales WHERE cd_codigo = @cd_sucursal AND ISNULL(@cd_bu,'')='';
				IF @id_tipoventa IS NULL SET @id_tipoventa = 1;

				SELECT TOP 1 @am_tcambiousd = am_tasa_cambio FROM dbo.Monedas_IATA WHERE cd_codigo = 'USD';
				IF @am_tcambiousd IS NULL SET @am_tcambiousd = 1.0;

				-- Calculate the total value of this invoice for verification
				SELECT @ValorFactura = SUM(
					CASE 
						WHEN Tipo = 'Aire' THEN (am_tarifa + am_iva + am_tua + am_comb + am_vat)
						ELSE am_tarifa + am_iva + am_vat
					END
				)
				FROM #GDSFacturacionAuto
				WHERE ReservaFactura = @ReservaFactura;

				UPDATE #GDSFacturacionAuto
				SET cd_Consecutivo_variablesadicionales = LEFT(REPLACE(CONVERT(VARCHAR(36), NEWID()), '-', ''), 10)
				WHERE tipo = 'SRV' AND cd_Consecutivo_variablesadicionales IS NULL

				-- Build dynamic SQL @SqlStmt
				SET @SqlStmt = '';
				SET @ItemIndex = 1;
				-- Clear and populate temporary table for concepts
				DELETE FROM #GenerarConceptosAuto;

				DECLARE @ZML_DatosXML VARCHAR(MAX);
				SET @ZML_DatosXML = 'SELECT 
										cd_cliente,
										cd_conceptofacturacion,
										cd_tiposervicio,
										in_nacionalidad,
										id_airolinea=(SELECT TOP 1 id FROM dbo.Entidades WHERE cd_siglas = ds_aero_code),
										id_moneda=(SELECT TOP 1 id FROM dbo.Monedas_IATA WHERE cd_codigo = ds_moneda),
										ds_pax_firstnm,
										ds_pax_lastnm,
										ds_pax_prefix,
										ds_paxClasificacion=NULL,
										ds_tkt_number,
										cd_proveedores,
										dt_checkin = Fecha_Salida,
										dt_checkout = Fecha_Llegada,
										cd_centrocosto,
										cd_auxiliar,
										cd_item=NULL,
										PNR,
										am_tarifa,
										am_total=CASE WHEN Tipo = ''Aire'' THEN (am_tarifa + am_iva + am_tua + am_comb + am_vat) ELSE (am_tarifa + am_iva + am_vat) END,
										Colld=CASE WHEN Tipo = ''Aire'' THEN id_air ELSE id_srv END,
										cd_Consecutivo_depende=cd_Consecutivo_variablesadicionales,
										am_Comision,
										am_ImpuestoComision=0,
										am_totalfactura=CASE WHEN Tipo = ''Aire'' THEN (am_tarifa + am_iva + am_tua + am_comb + am_vat) ELSE (am_tarifa + am_iva + am_vat) END,
										cd_tourcode,
										am_TarifaContado + am_IvaContado + am_OtrosContado,
										am_TarifaCredito + am_IvaCredito + am_OtrosCredito,
										cd_tktrevisado,
										id_TiposDocumento=(SELECT TOP 1 id FROM dbo.TiposDocumento WHERE cd_codigo = cd_TipoTiquete),
										cd_Penalidad,
										cd_TipoTiquete,
										am_TasaCambio,
										ds_itinerario,
										id_sucursal,
										id_implante=(SELECT TOP 1 id FROM dbo.Implantes WHERE cd_codigo = cd_implante),
										id_FormasPago,
										cd_TarjetaCredito=ds_cc_code,
										iden_gds,
										cd_codigotc = ds_cc_code,
										ds_numerotc = ds_cc_number,
										ds_vencetc = ds_cc_vence ,
										ds_autorizaciontc = ds_cc_autorizacion,
										ds_vouchertc = ds_cc_voucher,
										in_cuotastc = in_cc_cuotas,
										id_FormasPagoTAO = (SELECT TOP 1 id FROM dbo.FormasPago WHERE cd_codigo = cd_FormaPagoTAO),
										cd_codigotcTAO = cd_TarjetaCreditoTAO,
										ds_numerotcTAO = cd_NumeroTarjetaTAO,
										ds_vencetcTAO = cd_VencimientoTarjetaTAO ,
										ds_autorizaciontcTAO = ds_AutorizacionTarjetaTAO,
										ds_vouchertcTAO = ds_VoucherTarjetaTAO,
										in_cuotastcTAO = in_cuotasTarjetaTAO 
									FROM #GDSFacturacionAuto
									WHERE ReservaFactura = ''' + REPLACE(@ReservaFactura, '''', '''''') + ''';';

				EXEC dbo.spza_GenerarConceptosAutoJOB_Consultar
					@id_usuario = 1,
					@dt_fechaFactura = @FechaCont,
					@tasa_usd = @am_tcambiousd,
					@ZML_DatosXML = @ZML_DatosXML;

				
				DELETE FROM #CargosImpuestosJob;
				DELETE FROM #FormasPagosJob;
				
				DECLARE @id_reservas VARCHAR(8000);
				SET @id_reservas = CONVERT(VARCHAR(25),@id_reserva)+','
				
				INSERT INTO #CargosImpuestosJob EXEC dbo.spza_ReservasGDSJOB_CargosImpuestos @id_reservas = @id_reservas;
				INSERT INTO #FormasPagosJob EXEC dbo.spza_ReservasGDSJOB_FormasPagos @id_reservas = @id_reservas;
				
				-- Cursor over items in this invoice group (Only Aire / Tickets)
				DECLARE curItems CURSOR LOCAL FOR
				SELECT 
					Tipo, id, iden_gds, ds_fecha, ds_aero_code, ds_tkt_number, in_nacionalidad, am_tarifa, am_iva, am_tua, am_comb, am_vat, am_Comision,
					ds_pax_firstnm, ds_pax_lastnm, ds_pax_prefix, cd_tourcode, NumTktConj, cd_TipoTiquete, id_air, ds_itinerario, cd_Ahorro, ds_clases, ds_Observaciones,
					am_highfare, am_lowfare, ds_solicita, ds_lapsoviaje, cd_tktrevisado, cd_PasaportePax, cd_pax_CC, am_PorFacParcial, in_cantpax, Id_Precompra,
					cd_FormaPagoTAO, cd_TarjetaCreditoTAO, cd_NumeroTarjetaTAO, am_fptao, am_tao, am_ivatao, Id_Srv, cd_conceptofacturacion,
					cd_tiposervicio, cd_proveedores, ds_proveedores, cd_confirmation, dt_checkin, dt_checkout, cd_city, in_noches,
					Servicio, Descrip, am_TarifaContado, am_IvaContado, am_TarifaCredito, am_IvaCredito, cd_centrocosto, cd_auxiliar,
					cd_fp_OtrosItems, id_tipoproveedor, cd_tipoproveedor, ds_tipoproveedor, Fecha_Salida, Fecha_Llegada, PNR,
					ds_itinerarioaerolinea, ds_tkt_prefix, bl_ahorro, cd_VencimientoTarjetaTAO, cd_NumeroPolizaTAO, cd_AnexoPolizaTAO,
					ds_AutorizacionTarjetaTAO, in_cuotasTarjetaTAO, id_FormasPago, id_TarjetasCredito,
					am_fp1, ds_cc_code, ds_cc_number, ds_cc_vence, ds_cc_autorizacion, ds_cc_voucher, in_cc_cuotas,
					am_fp2, ds_cc_code2, ds_cc_number2, ds_cc_vence2, ds_cc_autorizacion2, ds_cc_voucher2, in_cc_cuotas2
				FROM #GDSFacturacionAuto
				WHERE ReservaFactura = @ReservaFactura AND Tipo = 'Aire';

				OPEN curItems;
				FETCH NEXT FROM curItems INTO 
					@item_Tipo, @item_id_reserva, @item_iden_gds, @item_ds_fecha, @item_ds_aero_code, @item_ds_tkt_number, @item_in_nacionalidad, @item_am_tarifa, @item_am_iva, @item_am_tua, @item_am_comb, @item_am_vat, @item_am_Comision,
					@item_ds_pax_firstnm, @item_ds_pax_lastnm, @item_ds_pax_prefix, @item_cd_tourcode, @item_NumTktConj, @item_cd_TipoTiquete, @item_id_air, @item_ds_itinerario, @item_cd_Ahorro, @item_ds_clases, @item_ds_Observaciones,
					@item_am_highfare, @item_am_lowfare, @item_ds_solicita, @item_ds_lapsoviaje, @item_cd_tktrevisado, @item_cd_PasaportePax, @item_cd_pax_CC, @item_am_PorFacParcial, @item_in_cantpax, @item_Id_Precompra,
					@item_cd_FormaPagoTAO, @item_TarjetaCreditoTAO, @item_NumeroTarjetaTAO, @item_am_fptao, @item_am_tao, @item_am_ivatao, @item_Id_Srv, @item_cd_conceptofacturacion,
					@item_cd_tiposervicio, @item_cd_proveedores, @item_ds_proveedores, @item_cd_confirmation, @item_dt_checkin, @item_dt_checkout, @item_cd_city, @item_in_noches,
					@item_Servicio, @item_Descrip, @item_am_TarifaContado, @item_am_IvaContado, @item_am_TarifaCredito, @item_am_IvaCredito, @item_cd_centrocosto, @item_cd_auxiliar,
					@item_cd_fp_OtrosItems, @item_id_tipoproveedor, @item_cd_tipoproveedor, @item_ds_tipoproveedor, @item_Fecha_Salida, @item_Fecha_Llegada, @item_PNR,
					@item_ds_itinerarioaerolinea, @item_ds_tkt_prefix, @item_bl_ahorro, @item_cd_VencimientoTarjetaTAO, @item_cd_NumeroPolizaTAO, @item_cd_AnexoPolizaTAO,
					@item_ds_AutorizacionTarjetaTAO, @item_in_cuotasTarjetaTAO, @item_id_FormasPago, @item_id_TarjetasCredito,
					@item_am_fp1, @item_ds_cc_code, @item_ds_cc_number, @item_ds_cc_vence, @item_ds_cc_autorizacion, @item_ds_cc_voucher, @item_in_cc_cuotas,
					@item_am_fp2, @item_ds_cc_code2, @item_ds_cc_number2, @item_ds_cc_vence2, @item_ds_cc_autorizacion2, @item_ds_cc_voucher2, @item_in_cc_cuotas2;				WHILE @@FETCH_STATUS = 0
				BEGIN
					-- Calculate Contado / Credito ratio
					SET @ContadoRatio = 0.0;
					IF @item_am_tarifa > 0
					BEGIN
						SET @ContadoRatio = CAST(@item_am_TarifaContado AS FLOAT) / CAST(@item_am_tarifa AS FLOAT);
					END
					ELSE IF @item_am_IvaContado > 0
					BEGIN
						SET @ContadoRatio = 1.0;
					END

					-- Resolve destination city from itinerary if not available
					SET @item_cd_destino = NULL;
					SELECT TOP 1 @item_cd_destino = cd_destino 
					FROM dbo.ReservaGDS_Itinerarios 
					WHERE id_reserva = @item_id_reserva 
					ORDER BY orden ASC;
					
					IF @item_cd_destino IS NULL
					BEGIN
						SET @item_cd_destino = 'XXX'; -- default fall-back if no itinerary
					END

					-- Resolving document type and entities for ticket
					DECLARE @id_TiposDocumento INT;
					SELECT @id_TiposDocumento = id FROM dbo.TiposDocumento WHERE cd_codigo = @item_cd_TipoTiquete;
					IF @id_TiposDocumento IS NULL
					BEGIN
						SELECT TOP 1 @id_TiposDocumento = id FROM dbo.TiposDocumento WHERE cd_codigo = 'TKT';
					END
					IF @id_TiposDocumento IS NULL SET @id_TiposDocumento = 1;

					DECLARE @id_entdist INT, @id_entvend INT, @bl_nogds BIT;
					SELECT @id_entvend = id ,@bl_nogds=bl_nogds FROM dbo.Entidades WHERE cd_siglas = @item_ds_aero_code OR cd_codigo = @item_ds_aero_code;

					IF ISNULL(@bl_nogds,0) = 1
					BEGIN
						SELECT TOP 1 @id_entdist = @id_entvend;
					END
					ELSE
					BEGIN
						SELECT TOP 1 @id_entdist = id FROM dbo.Entidades WHERE cd_siglas = 'BP' OR cd_codigo = 'BSP';
					END

					-- Insert ticket item into #TmpFacturaItems
					INSERT INTO #TmpFacturaItems (
						tipo_item, id_referencia_origen, cd_tiquete, in_nacionalidad, cd_cencosto, cd_auxiliar, cd_item,
						am_tarifa, am_iva, am_tua, am_comb, am_vat, am_Comision,
						ds_paxname, ds_paxape, ds_paxprefix, cd_tourcode, NumTktConj, cd_TipoTiquete, id_air,
						ds_itinerario, ds_itinerarioaerolinea, ds_clases, ds_Observaciones,
						am_highfare, am_lowfare, ds_solicita, ds_lapsoviaje, cd_tktrevisado, cd_PasaportePax, cd_pax_CC,
						am_PorFacParcial, in_cantpax, Id_Precompra, cd_FormaPagoTAO, cd_TarjetaCreditoTAO, cd_NumeroTarjetaTAO,
						cd_VencimientoTarjetaTAO, cd_NumeroPolizaTAO, cd_AnexoPolizaTAO, ds_AutorizacionTarjetaTAO, in_cuotasTarjetaTAO,
						id_FormasPago, id_TarjetasCredito, am_fp1, ds_cc_code, ds_cc_number, ds_cc_vence, ds_cc_autorizacion, ds_cc_voucher, in_cc_cuotas,
						am_fp2, ds_cc_code2, ds_cc_number2, ds_cc_vence2, ds_cc_autorizacion2, ds_cc_voucher2, in_cc_cuotas2,
						id_monedas_iata, Tcambio, id_sucursal, id_implante, bl_ahorro, cd_TipoTiqueteGDS, id_TiposDocumento, id_entdist, id_entvend,
						cd_destino, dt_fechaexped, id_tiqueteadores, id_gds, iden_gds, am_comisionPNR, ds_records, bl_NoCalcComision, bl_NoCalcIvaComision,
						am_basecomisionable, am_porcomision, OrdenGrabacion, CodigoReserva
					)
					VALUES (
						'TKT', @item_id_reserva, @item_ds_tkt_number, @item_in_nacionalidad, @item_cd_centrocosto, @item_cd_auxiliar, 'TKT',
						@item_am_tarifa, @item_am_iva, @item_am_tua, @item_am_comb, @item_am_vat, @item_am_Comision,
						@item_ds_pax_firstnm, @item_ds_pax_lastnm, @item_ds_pax_prefix, @item_cd_tourcode, @item_NumTktConj, @item_cd_TipoTiquete, @item_id_air,
						@item_ds_itinerario, @item_ds_itinerarioaerolinea, @item_ds_clases, @item_ds_Observaciones,
						@item_am_highfare, @item_am_lowfare, @item_ds_solicita, @item_ds_lapsoviaje, @item_cd_tktrevisado, @item_cd_PasaportePax, @item_cd_pax_CC,
						@item_am_PorFacParcial, @item_in_cantpax, @item_Id_Precompra, @item_cd_FormaPagoTAO, @item_TarjetaCreditoTAO, @item_NumeroTarjetaTAO,
						@item_cd_VencimientoTarjetaTAO, @item_cd_NumeroPolizaTAO, @item_cd_AnexoPolizaTAO, @item_ds_AutorizacionTarjetaTAO, @item_in_cuotasTarjetaTAO,
						@item_id_FormasPago, @item_id_TarjetasCredito, @item_am_fp1, @item_ds_cc_code, @item_ds_cc_number, @item_ds_cc_vence, @item_ds_cc_autorizacion, @item_ds_cc_voucher, @item_in_cc_cuotas,
						@item_am_fp2, @item_ds_cc_code2, @item_ds_cc_number2, @item_ds_cc_vence2, @item_ds_cc_autorizacion2, @item_ds_cc_voucher2, @item_in_cc_cuotas2,
						@id_monedas_iata, @am_TasaCambio, @id_sucursal, @id_implante, @item_bl_ahorro, @item_cd_TipoTiquete, @id_TiposDocumento, @id_entdist, @id_entvend,
						@item_cd_destino, @item_ds_fecha, @id_tiqueteador, @item_id_air, @item_iden_gds, @item_am_Comision, @item_PNR, 0, 0,
						@item_am_tarifa, 0, @ItemIndex, @item_PNR
					);

					DECLARE @NewItemId INT = SCOPE_IDENTITY();

					-- Cargos e Impuestos Tiquete
					IF EXISTS (
						SELECT 1 FROM #CargosImpuestosJob 
						WHERE id_reserva = @id_reserva 
						  AND id_reservaGDS_detalles = @item_id_air
					)
					BEGIN
						-- Priority 1: Use GDS bulk cargos e impuestos
						INSERT INTO #TmpFacturaCargos (id_item, cd_codigo, ds_nombre, cd_tipo, am_porcentaje, am_valor, am_contado, am_credito, id_carg, id_imp, bl_iva, in_orden)
						SELECT 
							@NewItemId,
							cd_codigo,
							ds_nombre,
							CASE WHEN cd_tipo='1' THEN 'C'
								 WHEN cd_tipo='2' THEN 'D'
								 WHEN cd_tipo='3' THEN 'I'
								 WHEN cd_tipo='4' THEN 'R'
							END,
							am_porcentaje,
							am_valor,
							am_contado,
							am_credito,
							CASE 
								WHEN cd_tipo IN ('1','2') 
								THEN (SELECT TOP 1 id FROM dbo.CargosDesc WHERE cd_codigo = cd_codigo)
								ELSE ISNULL((SELECT TOP 1 Id_cargo_dep FROM dbo.ImpRet WHERE cd_codigo = cd_codigo),1)
							END,
							CASE 
								WHEN cd_tipo IN ('3','4') 
								THEN (SELECT TOP 1 id FROM dbo.ImpRet WHERE cd_codigo = cd_codigo)
								ELSE NULL
							END,
							CASE WHEN cd_tipo IN ('3') AND (cd_codigo = 'IVA' OR (SELECT TOP 1 bl_iva FROM dbo.ImpRet WHERE cd_codigo = cd_codigo) = 1) THEN 1 ELSE 0 END,
							in_orden
						FROM #CargosImpuestosJob
						WHERE id_reserva = @id_reserva 
						  AND id_reservaGDS_detalles = @item_id_air;
					END
					ELSE
					BEGIN
						-- Fallback 2: Fixed charges/taxes + client configuration
						INSERT INTO #TmpFacturaCargos (id_item, cd_codigo, ds_nombre, cd_tipo, am_porcentaje, am_valor, am_contado, am_credito, id_carg, id_imp, bl_iva, in_orden)
						VALUES 
							(@NewItemId, 'TAR', 'Tarifa', 'C', 0, @item_am_tarifa, @item_am_TarifaContado, @item_am_TarifaCredito, 1, 0, 0, 1);

						IF @item_am_tua >= 0
						BEGIN
							DECLARE @id_carg_tua INT;
							SELECT @id_carg_tua = id FROM dbo.CargosDesc WHERE cd_codigo = 'TUA';
							INSERT INTO #TmpFacturaCargos (id_item, cd_codigo, ds_nombre, cd_tipo, am_porcentaje, am_valor, am_contado, am_credito, id_carg, id_imp, bl_iva, in_orden)
							VALUES (@NewItemId, 'TUA', 'Tasa Aeroportuaria', 'C', 0, @item_am_tua, @item_am_tua * @ContadoRatio, @item_am_tua * (1 - @ContadoRatio), @id_carg_tua, 0, 0, 2);
						END;

						IF @item_am_comb >= 0
						BEGIN
							DECLARE @id_carg_comb INT;
							SELECT @id_carg_comb = id FROM dbo.CargosDesc WHERE cd_codigo = 'CMB';
							INSERT INTO #TmpFacturaCargos (id_item, cd_codigo, ds_nombre, cd_tipo, am_porcentaje, am_valor, am_contado, am_credito, id_carg, id_imp, bl_iva, in_orden)
							VALUES (@NewItemId, 'CMB', 'Combustible', 'C', 0, @item_am_comb, @item_am_comb * @ContadoRatio, @item_am_comb * (1 - @ContadoRatio), @id_carg_comb, 0, 0, 3);
							
						END;

						IF @item_am_vat >= 0
						BEGIN
							DECLARE @id_carg_otr INT;
							SELECT @id_carg_otr = id FROM dbo.CargosDesc WHERE cd_codigo = 'OTR';
							INSERT INTO #TmpFacturaCargos (id_item, cd_codigo, ds_nombre, cd_tipo, am_porcentaje, am_valor, am_contado, am_credito, id_carg, id_imp, bl_iva, in_orden)
							VALUES (@NewItemId, 'OTR', 'Otros', 'C', 0, @item_am_vat, @item_am_vat * @ContadoRatio, @item_am_vat * (1 - @ContadoRatio), @id_carg_otr, 0, 0, 4);
						END;

						IF @item_am_iva >= 0
						BEGIN
							INSERT INTO #TmpFacturaCargos (id_item, cd_codigo, ds_nombre, cd_tipo, am_porcentaje, am_valor, am_contado, am_credito, id_carg, id_imp, bl_iva, in_orden)
							VALUES (@NewItemId, 'IVA', @ds_impas_iva, 'I', @am_porcentaje_iva, @item_am_iva, @item_am_IvaContado, @item_am_IvaCredito, 1, 1, 1, 1);
						END;

						-- Query concepts from spza_CargosImpAsignadosIntegradoJOB_ConsultarConceptoFac
						IF OBJECT_ID('tempdb..#TmpConceptoExtra') IS NOT NULL DROP TABLE #TmpConceptoExtra;
						CREATE TABLE #TmpConceptoExtra (
							Codigo VARCHAR(20), Concepto VARCHAR(100), Porcentaje NUMERIC(8,4), Editable CHAR(1), Calcular VARCHAR(20),
							Contado MONEY, Credito MONEY, Valor MONEY, id_carg INT, id_imp INT, Tipo CHAR(1), Nombre VARCHAR(100),
							Cuenta VARCHAR(16), Contabilizar BIT, Respuesta VARCHAR(1000), noshow BIT, id_cargo_dep INT, id_imp_dep INT,
							C_Orden INT, I_Orden INT, bl_iva BIT, bl_iva2 BIT
						);

						INSERT INTO #TmpConceptoExtra
						EXEC dbo.spza_CargosImpAsignadosIntegradoJOB_ConsultarConceptoFac 
							@id_usuario = 1, 
							@id_ConceptFac = @item_cd_conceptofacturacion, 
							@bu = @cd_bu, 
							@Id_Cliente = @cd_cliente;
						
						--IF @CalcularAutoValoresItemFac = 'S' OR EXISTS(SELECT id FROM dbo.ConceptoFacturacion WHERE id=@item_cd_conceptofacturacion AND bl_CalculoAutoValoresFacturacion=1)
						--BEGIN
						--	UPDATE #TmpConceptoExtra
						--	SET Valor = ROUND(@item_am_tarifa * (Porcentaje / 100.0), @NumDecimales),
						--		Contado = ROUND(@item_am_TarifaContado * (Porcentaje / 100.0), @NumDecimales),
						--		Credito = ROUND(@item_am_TarifaCredito * (Porcentaje / 100.0), @NumDecimales)
						--	WHERE Calcular = 'Calcular' AND Valor=0;
						--END;

						-- Exclude fixed ones ('TAR', 'TUA', 'CMB', 'OTR') and IVA (if already has IVA)
						DELETE FROM #TmpConceptoExtra WHERE Codigo IN ('TAR', 'TUA', 'CMB', 'OTR');
						IF EXISTS (SELECT 1 FROM #TmpFacturaCargos WHERE id_item = @NewItemId AND bl_iva = 1)
						BEGIN
							DELETE FROM #TmpConceptoExtra WHERE bl_iva = 1;
						END;

						INSERT INTO #TmpFacturaCargos (id_item, cd_codigo, ds_nombre, cd_tipo, am_porcentaje, am_valor, am_contado, am_credito, id_carg, id_imp, bl_iva, in_orden)
						SELECT 
							@NewItemId, Codigo, Concepto, Tipo, Porcentaje, Valor, Contado, Credito, id_carg, id_imp, bl_iva, C_Orden
						FROM #TmpConceptoExtra;

						DROP TABLE #TmpConceptoExtra;
					END;

					-- Formas de Pago Tiquete
					IF EXISTS (
						SELECT 1 FROM #FormasPagosJob 
						WHERE id_reserva = @id_reserva 
						  AND id_reservaGDS_detalles = @item_id_air
					)
					BEGIN
						-- Priority 1: Replace all with GDS bulk formas de pago
						INSERT INTO #TmpFacturaFormasPago (id_item, id_formaspago, cd_codigo, ds_nombre, id_tarjetascredito, cd_tipotarjeta, ds_numerotarjeta, ds_vouchertarjeta, ds_expiraciontarjeta, ds_autorizaciontarjeta, in_cuotas, cd_banco, ds_cheque, ds_plaza, ds_referencia, ds_Poliza, ds_PolizaAnexo, am_valor)
						SELECT 
							@NewItemId, id_formaspago, cd_codigo, ds_nombre, id_tarjetascredito, cd_tipotarjeta, ds_numerotarjeta, ds_vouchertarjeta, ds_expiraciontarjeta, ds_autorizaciontarjeta, in_coutas, cd_banco, ds_cheque, ds_plaza, ds_referencia, ds_Poliza, ds_PolizaAnexo, am_valor
						FROM #FormasPagosJob
						WHERE id_reserva = @id_reserva 
						  AND id_reservaGDS_detalles = @item_id_air;
					END
					ELSE
					BEGIN
						-- Fallback 2: Read payment methods from details/variables
						IF ISNULL(@item_am_fp1, 0) > 0
						BEGIN
							IF @item_ds_cc_code IS NOT NULL AND RTRIM(LTRIM(@item_ds_cc_code)) <> ''
							BEGIN
								DECLARE @fp_id_fp1 INT, @fp_id_tc1 INT;
								SELECT @fp_id_fp1 = id FROM dbo.FormasPago WHERE cd_codigo = 'TC';
								SELECT @fp_id_tc1 = id FROM dbo.tarjetascredito WHERE cd_codigo = @item_ds_cc_code;
								
								INSERT INTO #TmpFacturaFormasPago (id_item, id_formaspago, cd_codigo, ds_nombre, id_tarjetascredito, cd_tipotarjeta, ds_numerotarjeta, ds_vouchertarjeta, ds_expiraciontarjeta, ds_autorizaciontarjeta, in_cuotas, am_valor)
								VALUES (@NewItemId, @fp_id_fp1, 'TC', 'Tarjeta de Credito', @fp_id_tc1, @item_ds_cc_code, @item_ds_cc_number, @item_ds_cc_voucher, @item_ds_cc_vence, @item_ds_cc_autorizacion, ISNULL(@item_in_cc_cuotas, 1), @item_am_fp1);
							END
							ELSE
							BEGIN
								DECLARE @fp_id_fp_efe INT;
								SELECT @fp_id_fp_efe = id FROM dbo.FormasPago WHERE cd_codigo = 'EFE';
								INSERT INTO #TmpFacturaFormasPago (id_item, id_formaspago, cd_codigo, ds_nombre, am_valor)
								VALUES (@NewItemId, @fp_id_fp_efe, 'EFE', 'Efectivo', @item_am_fp1);
							END
						END;

						IF ISNULL(@item_am_fp2, 0) > 0
						BEGIN
							IF @item_ds_cc_code2 IS NOT NULL AND RTRIM(LTRIM(@item_ds_cc_code2)) <> ''
							BEGIN
								DECLARE @fp_id_fp2 INT, @fp_id_tc2 INT;
								SELECT @fp_id_fp2 = id FROM dbo.FormasPago WHERE cd_codigo = 'TC';
								SELECT @fp_id_tc2 = id FROM dbo.tarjetascredito WHERE cd_codigo = @item_ds_cc_code2;
								
								INSERT INTO #TmpFacturaFormasPago (id_item, id_formaspago, cd_codigo, ds_nombre, id_tarjetascredito, cd_tipotarjeta, ds_numerotarjeta, ds_vouchertarjeta, ds_expiraciontarjeta, ds_autorizaciontarjeta, in_cuotas, am_valor)
								VALUES (@NewItemId, @fp_id_fp2, 'TC', 'Tarjeta de credito', @fp_id_tc2, @item_ds_cc_code2, @item_ds_cc_number2, @item_ds_cc_voucher2, @item_ds_cc_vence2, @item_ds_cc_autorizacion2, ISNULL(@item_in_cc_cuotas2, 1), @item_am_fp2);
							END
							ELSE
							BEGIN
								DECLARE @fp_id_fp_efe2 INT;
								SELECT @fp_id_fp_efe2 = id FROM dbo.FormasPago WHERE cd_codigo = 'EFE';
								INSERT INTO #TmpFacturaFormasPago (id_item, id_formaspago, cd_codigo, ds_nombre, am_valor)
								VALUES (@NewItemId, @fp_id_fp_efe2, 'EFE', 'Efectivo', @item_am_fp2);
							END
						END;

						IF ISNULL(@item_am_fp1, 0) = 0 AND ISNULL(@item_am_fp2, 0) = 0 AND ISNULL(@item_am_tarifa, 0) > 0
						BEGIN
							DECLARE @fp_id_fp_default INT;
							SELECT @fp_id_fp_default = id FROM dbo.FormasPago WHERE cd_codigo = 'EFE';
							INSERT INTO #TmpFacturaFormasPago (id_item, id_formaspago, cd_codigo, ds_nombre, am_valor)
							VALUES (@NewItemId, @fp_id_fp_default, 'EFE', 'Efectivo', @item_am_tarifa);
						END;
						-- Recalcular valor de forma de pago si el parÃ¡metro 326 estÃ¡ activo
						IF @CalcularAutoValoresItemFac = 'S' OR EXISTS(SELECT id FROM dbo.ConceptoFacturacion WHERE id=@item_cd_conceptofacturacion AND bl_CalculoAutoValoresFacturacion=1)
						BEGIN
							SELECT @RecalcTotalValue = SUM(am_valor) FROM #TmpFacturaCargos WHERE id_item = @NewItemId;
							SELECT @RecalcTotalPayment = SUM(am_valor) FROM #TmpFacturaFormasPago WHERE id_item = @NewItemId;

							IF ISNULL(@RecalcTotalPayment, 0) <> ISNULL(@RecalcTotalValue, 0)
							BEGIN
								IF EXISTS (SELECT 1 FROM #TmpFacturaFormasPago WHERE id_item = @NewItemId)
								BEGIN
									UPDATE TOP (1) #TmpFacturaFormasPago
									SET am_valor = @RecalcTotalValue
									WHERE id_item = @NewItemId;
								END
							END;
						END;
					END;

					SET @ItemIndex = @ItemIndex + 1;
					FETCH NEXT FROM curItems INTO 
						@item_Tipo, @item_id_reserva, @item_iden_gds, @item_ds_fecha, @item_ds_aero_code, @item_ds_tkt_number, @item_in_nacionalidad, @item_am_tarifa, @item_am_iva, @item_am_tua, @item_am_comb, @item_am_vat, @item_am_Comision,
						@item_ds_pax_firstnm, @item_ds_pax_lastnm, @item_ds_pax_prefix, @item_cd_tourcode, @item_NumTktConj, @item_cd_TipoTiquete, @item_id_air, @item_ds_itinerario, @item_cd_Ahorro, @item_ds_clases, @item_ds_Observaciones,
						@item_am_highfare, @item_am_lowfare, @item_ds_solicita, @item_ds_lapsoviaje, @item_cd_tktrevisado, @item_cd_PasaportePax, @item_cd_pax_CC, @item_am_PorFacParcial, @item_in_cantpax, @item_Id_Precompra,
						@item_cd_FormaPagoTAO, @item_TarjetaCreditoTAO, @item_NumeroTarjetaTAO, @item_am_fptao, @item_am_tao, @item_am_ivatao, @item_Id_Srv, @item_cd_conceptofacturacion,
						@item_cd_tiposervicio, @item_cd_proveedores, @item_ds_proveedores, @item_cd_confirmation, @item_dt_checkin, @item_dt_checkout, @item_cd_city, @item_in_noches,
						@item_Servicio, @item_Descrip, @item_am_TarifaContado, @item_am_IvaContado, @item_am_TarifaCredito, @item_am_IvaCredito, @item_cd_centrocosto, @item_cd_auxiliar,
						@item_cd_fp_OtrosItems, @item_id_tipoproveedor, @item_cd_tipoproveedor, @item_ds_tipoproveedor, @item_Fecha_Salida, @item_Fecha_Llegada, @item_PNR,
						@item_ds_itinerarioaerolinea, @item_ds_tkt_prefix, @item_bl_ahorro, @item_cd_VencimientoTarjetaTAO, @item_cd_NumeroPolizaTAO, @item_cd_AnexoPolizaTAO,
						@item_ds_AutorizacionTarjetaTAO, @item_in_cuotasTarjetaTAO, @item_id_FormasPago, @item_id_TarjetasCredito,
						@item_am_fp1, @item_ds_cc_code, @item_ds_cc_number, @item_ds_cc_vence, @item_ds_cc_autorizacion, @item_ds_cc_voucher, @item_in_cc_cuotas,
						@item_am_fp2, @item_ds_cc_code2, @item_ds_cc_number2, @item_ds_cc_vence2, @item_ds_cc_autorizacion2, @item_ds_cc_voucher2, @item_in_cc_cuotas2;
				END;

				CLOSE curItems;
				DEALLOCATE curItems;

				-- Cursor over concepts returned by spza_GenerarConceptosAuto_Consultar
				DECLARE curConcepts CURSOR LOCAL FOR
				SELECT 
					id_ConceptoFacturacion, cd_ConceptoFacturacion, ds_ConceptoFacturacion, id_TiposConceptFac, bl_contorlarCargImp, bl_CalculoAutoValoresFacturacion, id_TiposServicio, cd_TiposServicio, ds_TiposServicio, cd_proveedores, ds_proveedores, cd_tiquete, ds_servicio, ds_descrip, ds_paxname, ds_paxape, cd_paxtype, ds_paxClasificacion, in_nacionalidad, dt_llegada, dt_salida, cd_cencosto, cd_auxiliar, cd_item, Valor, am_Contado, am_Credito, ColId, cd_Consecutivo_depende, CodigoReserva, am_ImpuestoComision, Respuesta, bl_RutaExentaIva, id_FormasPago, id_TarjetasCredito, am_basedescuento, am_pordescuento, id_FormasPagoAirPlus, cd_FormasPagoAirPlus, ds_FormasPagoAirPlus, id_TarjetasCreditoAirPlus, cd_TarjetasCreditoAirPlus, ds_numerotarjetaAirPlus, cd_codigotc, ds_numerotc, ds_vencetc, ds_autorizaciontc, ds_vouchertc, in_cuotastc 
				FROM #GenerarConceptosAuto;

				OPEN curConcepts;
				FETCH NEXT FROM curConcepts INTO 
					@c_id_ConceptoFacturacion, @c_cd_ConceptoFacturacion, @c_ds_ConceptoFacturacion, @c_id_TiposConceptFac, @c_bl_contorlarCargImp, @c_bl_CalculoAutoValoresFacturacion, @c_id_TiposServicio, @c_cd_TiposServicio, @c_ds_TiposServicio, @c_cd_proveedores, @c_ds_proveedores, @c_cd_tiquete, @c_ds_servicio, @c_ds_descrip, @c_ds_paxname, @c_ds_paxape, @c_cd_paxtype, @c_ds_paxClasificacion, @c_in_nacionalidad, @c_dt_llegada, @c_dt_salida, @c_cd_cencosto, @c_cd_auxiliar, @c_cd_item, @c_Valor, @c_am_Contado, @c_am_Credito, @c_ColId, @c_cd_Consecutivo_depende, @c_CodigoReserva, @c_am_ImpuestoComision, @c_Respuesta, @c_bl_RutaExentaIva, @c_id_FormasPago, @c_id_TarjetasCredito, @c_am_basedescuento, @c_am_pordescuento, @c_id_FormasPagoAirPlus, @c_cd_FormasPagoAirPlus, @c_ds_FormasPagoAirPlus, @c_id_TarjetasCreditoAirPlus, @c_cd_TarjetasCreditoAirPlus, @c_ds_numerotarjetaAirPlus, @c_cd_codigotc, @c_ds_numerotc, @c_ds_vencetc, @c_ds_autorizaciontc, @c_ds_vouchertc, @c_in_cuotastc;

				WHILE @@FETCH_STATUS = 0
				BEGIN
					DECLARE @c_tipo_item VARCHAR(10);
					SET @c_ValorIva=0;
					SET @c_PorIva = @am_porcentaje_iva;
					SET @c_Total = @c_Valor;
					SET @c_codigoimpiva = 'IVA';
					SET @c_nombreimpiva = @ds_impas_iva;
					SET @c_am_ContadoIva = 0;
					SET @c_am_CreditoIva = 0;
					IF @c_cd_ConceptoFacturacion IN ('CAN', 'CAI')
					BEGIN
						SET @c_tipo_item = 'TAO';
						SELECT @c_codigoimpiva= ISNULL(RTRIM(LTRIM(Valor)),'') from parametros where id = 331 AND @c_in_nacionalidad=2
						SELECT @c_codigoimpiva= ISNULL(RTRIM(LTRIM(Valor)),'IVA') from parametros where id = 330 AND @c_in_nacionalidad=1
						select @c_PorIva = CONVERT(NUMERIC(5,2),ISNULL(RTRIM(LTRIM(Valor)),'0')) from parametros where id = 389
						SELECT @c_PorIva = am_porcentaje FROM dbo.ImpRet WHERE cd_codigo=@c_codigoimpiva AND am_porcentaje<>0
						SELECT @c_nombreimpiva = ds_nombre FROM dbo.ImpRet WHERE cd_codigo=@c_codigoimpiva
						IF ISNULL(@c_Poriva,0)<>0
						BEGIN
							SET @c_ValorIva=ROUND((@c_Valor * (@c_Poriva/100)),@NumDecimales);
							SET @c_Total = @c_Valor + @c_ValorIva;
						END
						SET @c_am_ContadoIva = CASE WHEN ISNULL(@c_am_Contado,0)<>0 THEN @c_ValorIva ELSE 0 END
						SEt @c_am_CreditoIva = CASE WHEN ISNULL(@c_am_Credito,0)<>0 THEN @c_ValorIva ELSE 0 END
					END
					ELSE
					BEGIN
						SET @c_tipo_item = 'SRV';
					END

					DECLARE @c_id_reserva_int INT;
					SELECT TOP 1 @c_id_reserva_int = id FROM dbo.ReservasGDS WHERE cd_codigo = @c_CodigoReserva;

					INSERT INTO #TmpFacturaItems (
						tipo_item, id_referencia_origen, cd_tiquete, ds_descrip, in_nacionalidad, cd_cencosto, cd_auxiliar, cd_item, 
						am_tarifa, am_iva, am_valor_total,
						ds_paxname, ds_paxape, ds_paxprefix, cd_tourcode,
						ds_servicio, cd_proveedores, ds_proveedores,
						dt_llegada, dt_salida, am_pordescuento, am_basedescuento,
						id_FormasPago, id_TarjetasCredito, am_fp1, ds_cc_code, ds_cc_number, ds_cc_vence, ds_cc_autorizacion, ds_cc_voucher, in_cc_cuotas, 
						id_FormasPagoAirPlus, cd_FormasPagoAirPlus, ds_FormasPagoAirPlus, id_TarjetasCreditoAirPlus, cd_TarjetasCreditoAirPlus, ds_numerotarjetaAirPlus,
						id_TiposConceptFac, id_conceptofacturacion, id_tiposservicio,
						id_monedas_iata, Tcambio, CodigoReserva, ColId, id_reserva, cd_Consecutivo_depende
					)
					VALUES (
						@c_tipo_item, TRY_CAST(@c_ColId AS INT), @c_cd_tiquete, @c_ds_descrip, @c_in_nacionalidad,
						@c_cd_cencosto, @c_cd_auxiliar, @c_cd_item, @c_Valor, @c_valorIva, @c_Total,
						@c_ds_paxname, @c_ds_paxape, @c_cd_paxtype, NULL,
						@c_ds_servicio, @c_cd_proveedores, @c_ds_proveedores,
						@c_dt_llegada, @c_dt_salida, @c_am_pordescuento, @c_am_basedescuento,
						@c_id_FormasPago, @c_id_TarjetasCredito, @c_Total, @c_cd_codigotc, @c_ds_numerotc, @c_ds_vencetc, @c_ds_autorizaciontc, @c_ds_vouchertc, @c_in_cuotastc, 
						@c_id_FormasPagoAirPlus, @c_cd_FormasPagoAirPlus, @c_ds_FormasPagoAirPlus, @c_id_TarjetasCreditoAirPlus, @c_cd_TarjetasCreditoAirPlus, @c_ds_numerotarjetaAirPlus,
						@c_id_TiposConceptFac, @c_id_ConceptoFacturacion, @c_id_TiposServicio,
						@id_monedas_iata, @am_TasaCambio, @c_CodigoReserva, @c_ColId, @c_id_reserva_int, @c_cd_Consecutivo_depende
					);

					

					DECLARE @NewConceptItemId INT = SCOPE_IDENTITY();

					-- Cargos e Impuestos Concepto
					IF @c_id_reserva_int IS NOT NULL AND @c_ColId IS NOT NULL AND EXISTS (
						SELECT 1 FROM #CargosImpuestosJob 
						WHERE id_reserva = @c_id_reserva_int 
						  AND id_reservaGDS_servicios = TRY_CAST(@c_ColId AS INT)
					)
					BEGIN
						-- Priority 1: Replace all with GDS bulk data
						INSERT INTO #TmpFacturaCargos (id_item, cd_codigo, ds_nombre, cd_tipo, am_porcentaje, am_valor, am_contado, am_credito, id_carg, id_imp, bl_iva, in_orden)
						SELECT 
							@NewConceptItemId,
							cd_codigo,
							ds_nombre,
							CASE WHEN cd_tipo='1' THEN 'C'
								 WHEN cd_tipo='2' THEN 'D'
								 WHEN cd_tipo='3' THEN 'I'
								 WHEN cd_tipo='4' THEN 'R'
							END,
							am_porcentaje,
							am_valor,
							am_contado,
							am_credito,
							CASE 
								WHEN cd_tipo IN ('1','2') THEN
									CASE WHEN ISNUMERIC(cd_codigo) = 1 THEN CAST(cd_codigo AS INT)
										 ELSE (SELECT TOP 1 id FROM dbo.CargosDesc WHERE cd_codigo = cd_codigo)
									END
								ELSE NULL
							END,
							CASE 
								WHEN cd_tipo IN ('3','4') THEN
									CASE WHEN ISNUMERIC(cd_codigo) = 1 THEN CAST(cd_codigo AS INT)
										 ELSE (SELECT TOP 1 id FROM dbo.ImpRet WHERE cd_codigo = cd_codigo)
									END
								ELSE NULL
							END,
							CASE WHEN cd_tipo IN ('3','4') AND (cd_codigo = 'IVA' OR (SELECT TOP 1 bl_iva FROM dbo.ImpRet WHERE cd_codigo = cd_codigo) = 1) THEN 1 ELSE 0 END,
							in_orden
						FROM #CargosImpuestosJob
						WHERE id_reserva = @c_id_reserva_int 
						  AND id_reservaGDS_servicios = TRY_CAST(@c_ColId AS INT);
					END
					ELSE
					BEGIN
						-- Fallback 2: Fixed charges/taxes according to type
						IF @c_tipo_item = 'TAO'
						BEGIN
							-- For TAO: TAR, OTR, IVA
							INSERT INTO #TmpFacturaCargos (id_item, cd_codigo, ds_nombre, cd_tipo, am_porcentaje, am_valor, am_contado, am_credito, id_carg, id_imp, bl_iva, in_orden)
							VALUES 
								(@NewConceptItemId, 'TAR', 'Tarifa', 'C', 0, @c_Valor, @c_am_Contado, @c_am_Credito, 1, 0, 0, 1),
								(@NewConceptItemId, 'OTR', 'Otros', 'C', 0, 0, 0, 0, 1, 0, 0, 2);

							IF ISNULL(@c_ValorIva, 0) >= 0
							BEGIN
								INSERT INTO #TmpFacturaCargos (id_item, cd_codigo, ds_nombre, cd_tipo, am_porcentaje, am_valor, am_contado, am_credito, id_carg, id_imp, bl_iva, in_orden)
								VALUES (@NewConceptItemId, @c_codigoimpiva, @c_nombreimpiva, 'I', @c_PorIva, @c_ValorIva, @c_am_ContadoIva, @c_am_CreditoIva, 1, 1, 1, 1);
							END;
						END
						ELSE
						BEGIN
							-- For Services/Fees: TAR, IVA
							INSERT INTO #TmpFacturaCargos (id_item, cd_codigo, ds_nombre, cd_tipo, am_porcentaje, am_valor, am_contado, am_credito, id_carg, id_imp, bl_iva, in_orden)
							VALUES (@NewConceptItemId, 'TAR', 'Tarifa', 'C', 0, @c_Valor, @c_am_Contado, @c_am_Credito, 1, 0, 0, 1),
								   (@NewConceptItemId, 'OTR', 'Otros', 'C', 0, 0, 0, 0, 1, 0, 0, 2);

							IF ISNULL(@c_ValorIva, 0) >= 0
							BEGIN
								INSERT INTO #TmpFacturaCargos (id_item, cd_codigo, ds_nombre, cd_tipo, am_porcentaje, am_valor, am_contado, am_credito, id_carg, id_imp, bl_iva, in_orden)
								VALUES (@NewConceptItemId, 'IVA', @ds_impas_iva, 'I', @c_PorIva,  @c_ValorIva, @c_am_ContadoIva, @c_am_CreditoIva, 1, 1, 1, 1);
							END;
						END;

						-- Query configured concepts from spza_CargosImpAsignadosIntegradoJOB_ConsultarConceptoFac
						IF OBJECT_ID('tempdb..#TmpConceptoExtraAuto') IS NOT NULL DROP TABLE #TmpConceptoExtraAuto;
						CREATE TABLE #TmpConceptoExtraAuto (
							Codigo VARCHAR(20), Concepto VARCHAR(100), Porcentaje NUMERIC(8,4), Editable CHAR(1), Calcular VARCHAR(20),
							Contado MONEY, Credito MONEY, Valor MONEY, id_carg INT, id_imp INT, Tipo CHAR(1), Nombre VARCHAR(100),
							Cuenta VARCHAR(16), Contabilizar BIT, Respuesta VARCHAR(1000), noshow BIT, id_cargo_dep INT, id_imp_dep INT,
							C_Orden INT, I_Orden INT, bl_iva BIT, bl_iva2 BIT
						);

						INSERT INTO #TmpConceptoExtraAuto
						EXEC dbo.spza_CargosImpAsignadosIntegradoJOB_ConsultarConceptoFac 
							@id_usuario = 1, 
							@id_ConceptFac = @c_id_ConceptoFacturacion, 
							@bu = @cd_bu, 
							@Id_Cliente = @cd_cliente;

						-- Exclude fixed ones ('TAR', 'OTR') and IVA (if already has IVA)
						DELETE FROM #TmpConceptoExtraAuto WHERE Codigo IN ('TAR', 'OTR');
						IF EXISTS (SELECT 1 FROM #TmpFacturaCargos WHERE id_item = @NewConceptItemId AND bl_iva = 1)
						BEGIN
							DELETE FROM #TmpConceptoExtraAuto WHERE bl_iva = 1;
						END;

						INSERT INTO #TmpFacturaCargos (id_item, cd_codigo, ds_nombre, cd_tipo, am_porcentaje, am_valor, am_contado, am_credito, id_carg, id_imp, bl_iva, in_orden)
						SELECT 
							@NewConceptItemId, Codigo, Concepto, Tipo, Porcentaje, Valor, Contado, Credito, id_carg, id_imp, bl_iva, C_Orden
						FROM #TmpConceptoExtraAuto;

						DROP TABLE #TmpConceptoExtraAuto;
					END;
								
				
					-- Formas de Pago Concepto
					IF @c_id_reserva_int IS NOT NULL AND @c_ColId IS NOT NULL AND EXISTS (
						SELECT 1 FROM #FormasPagosJob 
						WHERE id_reserva = @c_id_reserva_int 
						  AND id_reservaGDS_servicios = TRY_CAST(@c_ColId AS INT)
					)
					BEGIN
						-- Priority 1: Replace all with GDS bulk data
						INSERT INTO #TmpFacturaFormasPago (id_item, id_formaspago, cd_codigo, ds_nombre, id_tarjetascredito, cd_tipotarjeta, ds_numerotarjeta, ds_vouchertarjeta, ds_expiraciontarjeta, ds_autorizaciontarjeta, in_cuotas, cd_banco, ds_cheque, ds_plaza, ds_referencia, ds_Poliza, ds_PolizaAnexo, am_valor)
						SELECT 
							@NewConceptItemId, id_formaspago, cd_codigo, ds_nombre, id_tarjetascredito, cd_tipotarjeta, ds_numerotarjeta, ds_vouchertarjeta, ds_expiraciontarjeta, ds_autorizaciontarjeta, in_coutas, cd_banco, ds_cheque, ds_plaza, ds_referencia, ds_Poliza, ds_PolizaAnexo, am_valor
						FROM #FormasPagosJob
						WHERE id_reserva = @c_id_reserva_int 
						  AND id_reservaGDS_servicios = TRY_CAST(@c_ColId AS INT);
					END
					ELSE
					BEGIN
						-- Fallback 2: Inherit or fallback payment methods
						IF @c_id_FormasPago IS NOT NULL AND @c_id_TarjetasCredito IS NOT NULL
						BEGIN
							DECLARE @fp_nombre_tao2 VARCHAR(50);
							DECLARE @tc_codigo_tao2 VARCHAR(4);
							DECLARE @tc_numero_tao2 VARCHAR(25);
							DECLARE @tc_id_tc_tao2 INT;
							SET @tc_numero_tao2 = @item_ds_cc_number;
							SET @tc_codigo_tao2 = @item_ds_cc_code;
							
							SELECT @fp_nombre_tao2 = ds_nombre FROM dbo.FormasPago WHERE id = @c_id_FormasPago;
							SELECT @tc_id_tc_tao2 = id FROM dbo.tarjetascredito WHERE cd_codigo = @tc_codigo_tao2;

							--INSERT INTO #TmpFacturaFormasPago (id_item, id_formaspago, cd_codigo, ds_nombre, id_tarjetascredito, cd_tipotarjeta, ds_numerotarjeta, am_valor)
							--VALUES (@NewConceptItemId, @c_id_FormasPago, 'TC', @fp_nombre_tao2, @tc_id_tc_tao2, @tc_codigo_tao2, @tc_numero_tao2, @c_Valor);

							INSERT INTO #TmpFacturaFormasPago (id_item, id_formaspago, cd_codigo, ds_nombre, id_tarjetascredito, cd_tipotarjeta, ds_numerotarjeta, ds_vouchertarjeta, ds_expiraciontarjeta, ds_autorizaciontarjeta, in_cuotas, am_valor)
							VALUES (@NewConceptItemId, @c_id_FormasPago, 'TC', 'Tarjeta de Credito', @c_id_TarjetasCredito, @c_cd_codigotc, @c_ds_numerotc, @c_ds_vouchertc, @c_ds_vencetc, @c_ds_autorizaciontc, ISNULL(@c_in_cuotastc, 1), @c_Valor);
						END
						ELSE IF @c_id_FormasPagoAirPlus IS NOT NULL
						BEGIN
							INSERT INTO #TmpFacturaFormasPago (id_item, id_formaspago, cd_codigo, ds_nombre, id_tarjetascredito, cd_tipotarjeta, ds_numerotarjeta, am_valor)
							VALUES (@NewConceptItemId, @c_id_FormasPagoAirPlus, @c_cd_FormasPagoAirPlus, @c_ds_FormasPagoAirPlus, @c_id_TarjetasCreditoAirPlus, @c_cd_TarjetasCreditoAirPlus, @c_ds_numerotarjetaAirPlus, @c_Valor);
						END
						ELSE
						BEGIN
							DECLARE @fp_id_efe_default INT;
							SELECT @fp_id_efe_default = id FROM dbo.FormasPago WHERE cd_codigo = 'EFE';
							INSERT INTO #TmpFacturaFormasPago (id_item, id_formaspago, cd_codigo, ds_nombre, am_valor)
							VALUES (@NewConceptItemId, @fp_id_efe_default, 'EFE', 'Efectivo', @c_Valor);
						END;
						-- Recalcular valor de forma de pago si el parÃ¡metro 326 estÃ¡ activo
						IF @CalcularAutoValoresItemFac = 'S' OR EXISTS(SELECT id FROM dbo.ConceptoFacturacion WHERE id=@item_cd_conceptofacturacion AND bl_CalculoAutoValoresFacturacion=1)
						BEGIN
							SELECT @RecalcTotalValue = SUM(am_valor) FROM #TmpFacturaCargos WHERE id_item = @NewConceptItemId;
							SELECT @RecalcTotalPayment = SUM(am_valor) FROM #TmpFacturaFormasPago WHERE id_item = @NewConceptItemId;

							IF ISNULL(@RecalcTotalPayment, 0) <> ISNULL(@RecalcTotalValue, 0)
							BEGIN
								IF EXISTS (SELECT 1 FROM #TmpFacturaFormasPago WHERE id_item = @NewConceptItemId)
								BEGIN
									UPDATE TOP (1) #TmpFacturaFormasPago
									SET am_valor = @RecalcTotalValue
									WHERE id_item = @NewConceptItemId;
								END
							END;
						END;
					END;

					SET @ItemIndex = @ItemIndex + 1;
					FETCH NEXT FROM curConcepts INTO 
						@c_id_ConceptoFacturacion, @c_cd_ConceptoFacturacion, @c_ds_ConceptoFacturacion, @c_id_TiposConceptFac, @c_bl_contorlarCargImp, @c_bl_CalculoAutoValoresFacturacion, @c_id_TiposServicio, @c_cd_TiposServicio, @c_ds_TiposServicio, @c_cd_proveedores, @c_ds_proveedores, @c_cd_tiquete, @c_ds_servicio, @c_ds_descrip, @c_ds_paxname, @c_ds_paxape, @c_cd_paxtype, @c_ds_paxClasificacion, @c_in_nacionalidad, @c_dt_llegada, @c_dt_salida, @c_cd_cencosto, @c_cd_auxiliar, @c_cd_item, @c_Valor, @c_am_Contado, @c_am_Credito, @c_ColId, @c_cd_Consecutivo_depende, @c_CodigoReserva, @c_am_ImpuestoComision, @c_Respuesta, @c_bl_RutaExentaIva, @c_id_FormasPago, @c_id_TarjetasCredito, @c_am_basedescuento, @c_am_pordescuento, @c_id_FormasPagoAirPlus, @c_cd_FormasPagoAirPlus, @c_ds_FormasPagoAirPlus, @c_id_TarjetasCreditoAirPlus, @c_cd_TarjetasCreditoAirPlus, @c_ds_numerotarjetaAirPlus, @c_cd_codigotc, @c_ds_numerotc, @c_ds_vencetc, @c_ds_autorizaciontc, @c_ds_vouchertc, @c_in_cuotastc;
				END;

				CLOSE curConcepts;
				DEALLOCATE curConcepts;

				-- Generar cd_Consecutivo_variablesadicionales aleatorio para los servicios padres
				UPDATE #TmpFacturaItems
				SET cd_Consecutivo_variablesadicionales = LEFT(REPLACE(CONVERT(VARCHAR(36), NEWID()), '-', ''), 10)
				WHERE tipo_item = 'SRV' AND cd_Consecutivo_variablesadicionales IS NULL
				 
				UPDATE C
				SET C.am_valor = ROUND(p.am_valor * (C.am_porcentaje/ 100.0), @NumDecimales),
					C.am_contado = ROUND(p.am_contado * (C.am_porcentaje / 100.0), @NumDecimales),
					C.am_Credito = ROUND(p.am_Credito * (C.am_porcentaje / 100.0), @NumDecimales)
				FROM #TmpFacturaCargos C
				INNER JOIN #TmpFacturaCargos P ON P.id_cargo_temp <> C.id_cargo_temp AND P.id_item = C.id_item AND p.id_carg = C.id_carg AND ISNULL(P.am_valor,0)<>0 AND P.cd_tipo = 'C'
				INNER JOIN #TmpFacturaItems FI ON FI.id_item = C.id_item
				inner join dbo.ConceptoFacturacion CF ON CF.id = FI.id_conceptofacturacion
				WHERE ISNULL(C.am_valor,0)=0 AND ISNULL(C.am_porcentaje,0)<>0 AND C.cd_tipo IN ('I') AND (@CalcularAutoValoresItemFac = 'S' OR CF.bl_CalculoAutoValoresFacturacion=1);	

				UPDATE FP
				SET FP.am_valor=ISNULL((SELECT SUM(C.am_valor) FROM #TmpFacturaCargos C WHERE C.id_item = FP.id_item AND ISNULL(C.am_valor,0)<>0),FP.am_valor) 
				FROM #TmpFacturaFormasPago FP
				INNER JOIN #TmpFacturaItems FI ON FI.id_item = FP.id_item
				INNER JOIN dbo.ConceptoFacturacion CF ON CF.id = FI.id_conceptofacturacion
				WHERE (@CalcularAutoValoresItemFac = 'S' OR CF.bl_CalculoAutoValoresFacturacion=1);

				-- Reconstruct dynamic @SqlStmt from tables
				SET @SqlStmt = '';
				SET @ItemIndex = 1;

				DECLARE @gen_id_item INT, @gen_tipo_item VARCHAR(10), @gen_cd_tiquete VARCHAR(50), @gen_ds_descrip VARCHAR(500), @gen_in_nacionalidad INT, @gen_cd_cencosto VARCHAR(50), @gen_cd_auxiliar VARCHAR(50), @gen_cd_item VARCHAR(50), @gen_am_tarifa MONEY, @gen_am_iva MONEY, @gen_am_tua MONEY, @gen_am_comb MONEY, @gen_am_vat MONEY, @gen_am_Comision MONEY, @gen_ds_paxname VARCHAR(30), @gen_ds_paxape VARCHAR(30), @gen_ds_paxprefix CHAR(3), @gen_cd_tourcode VARCHAR(25), @gen_NumTktConj INT, @gen_cd_TipoTiquete CHAR(3), @gen_id_air INT, @gen_ds_itinerario VARCHAR(250), @gen_ds_itinerarioaerolinea VARCHAR(128), @gen_ds_clases VARCHAR(61), @gen_ds_Observaciones VARCHAR(8000), @gen_am_highfare MONEY, @gen_am_lowfare MONEY, @gen_ds_solicita VARCHAR(200), @gen_ds_lapsoviaje VARCHAR(50), @gen_cd_tktrevisado VARCHAR(14), @gen_cd_PasaportePax VARCHAR(25), @gen_cd_pax_CC VARCHAR(20), @gen_am_PorFacParcial MONEY, @gen_in_cantpax INT, @gen_Id_Precompra INT, @gen_id_FormasPago INT, @gen_id_TarjetasCredito INT, @gen_id_sucursal INT, @gen_id_implante INT, @gen_bl_ahorro BIT, @gen_cd_TipoTiqueteGDS VARCHAR(3), @gen_id_TiposDocumento INT, @gen_id_entdist INT, @gen_id_entvend INT, @gen_cd_destino VARCHAR(3), @gen_dt_fechaexped SMALLDATETIME, @gen_id_tiqueteadores INT, @gen_id_gds INT, @gen_iden_gds INT, @gen_am_comisionPNR MONEY, @gen_ds_records VARCHAR(62), @gen_bl_NoCalcComision BIT, @gen_bl_NoCalcIvaComision BIT, @gen_am_basecomisionable MONEY, @gen_am_porcomision MONEY, @gen_id_tiposconceptfac INT, @gen_id_conceptofacturacion INT, @gen_id_tiposservicio INT, @gen_cd_proveedores VARCHAR(25), @gen_ds_servicio VARCHAR(250), @gen_am_valorprov MONEY, @gen_id_monedaprov INT, @gen_dt_llegada SMALLDATETIME, @gen_dt_salida SMALLDATETIME, @gen_am_pordescuento NUMERIC(8,4), @gen_Fecha_Salida SMALLDATETIME, @gen_Fecha_Llegada SMALLDATETIME, @gen_am_basedescuento MONEY, @gen_cd_Consecutivo_depende VARCHAR(50), @gen_cd_Consecutivo_variablesadicionales VARCHAR(50), @gen_id_referencia_origen INT;

				DECLARE curGenItems CURSOR LOCAL FAST_FORWARD FOR
				SELECT 
					id_item, tipo_item, cd_tiquete, ds_descrip, in_nacionalidad, cd_cencosto, cd_auxiliar, cd_item, am_tarifa, am_iva, am_tua, am_comb, am_vat, am_Comision,
					ds_paxname, ds_paxape, ds_paxprefix, cd_tourcode, NumTktConj, cd_TipoTiquete, id_air, ds_itinerario, ds_itinerarioaerolinea, ds_clases, ds_Observaciones,
					am_highfare, am_lowfare, ds_solicita, ds_lapsoviaje, cd_tktrevisado, cd_PasaportePax, cd_pax_CC, am_PorFacParcial, in_cantpax, Id_Precompra,
					id_FormasPago, id_TarjetasCredito, id_sucursal, id_implante, bl_ahorro, cd_TipoTiqueteGDS, id_TiposDocumento, id_entdist, id_entvend,
					cd_destino, dt_fechaexped, id_tiqueteadores, id_gds, iden_gds, am_comisionPNR, ds_records, bl_NoCalcComision, bl_NoCalcIvaComision,
					am_basecomisionable, am_porcomision, id_tiposconceptfac, id_conceptofacturacion, id_tiposservicio, cd_proveedores, ds_servicio,
					am_valorprov, id_monedaprov, dt_llegada, dt_salida, am_pordescuento, Fecha_Salida, Fecha_Llegada, am_basedescuento, cd_Consecutivo_depende, cd_Consecutivo_variablesadicionales, id_referencia_origen
				FROM #TmpFacturaItems
				ORDER BY id_item;

				IF OBJECT_ID('tempdb..#TmpVariablesObtenidas') IS NOT NULL DROP TABLE #TmpVariablesObtenidas;
				CREATE TABLE #TmpVariablesObtenidas (
					Iden_Variable INT,
					Nombre VARCHAR(100) COLLATE DATABASE_DEFAULT,
					ValorObtenido VARCHAR(MAX) COLLATE DATABASE_DEFAULT,
					Id_Reserva INT,
					IDEN_Maestro INT,
					cd_Maestro VARCHAR(50) COLLATE DATABASE_DEFAULT
				);

				OPEN curGenItems;
				FETCH NEXT FROM curGenItems INTO 
					@gen_id_item, @gen_tipo_item, @gen_cd_tiquete, @gen_ds_descrip, @gen_in_nacionalidad, @gen_cd_cencosto, @gen_cd_auxiliar, @gen_cd_item, @gen_am_tarifa, @gen_am_iva, @gen_am_tua, @gen_am_comb, @gen_am_vat, @gen_am_Comision,
					@gen_ds_paxname, @gen_ds_paxape, @gen_ds_paxprefix, @gen_cd_tourcode, @gen_NumTktConj, @gen_cd_TipoTiquete, @gen_id_air, @gen_ds_itinerario, @gen_ds_itinerarioaerolinea, @gen_ds_clases, @gen_ds_Observaciones,
					@gen_am_highfare, @gen_am_lowfare, @gen_ds_solicita, @gen_ds_lapsoviaje, @gen_cd_tktrevisado, @gen_cd_PasaportePax, @gen_cd_pax_CC, @gen_am_PorFacParcial, @gen_in_cantpax, @gen_Id_Precompra,
					@gen_id_FormasPago, @gen_id_TarjetasCredito, @gen_id_sucursal, @gen_id_implante, @gen_bl_ahorro, @gen_cd_TipoTiqueteGDS, @gen_id_TiposDocumento, @gen_id_entdist, @gen_id_entvend,
					@gen_cd_destino, @gen_dt_fechaexped, @gen_id_tiqueteadores, @gen_id_gds, @gen_iden_gds, @gen_am_comisionPNR, @gen_ds_records, @gen_bl_NoCalcComision, @gen_bl_NoCalcIvaComision,
					@gen_am_basecomisionable, @gen_am_porcomision, @gen_id_tiposconceptfac, @gen_id_conceptofacturacion, @gen_id_tiposservicio, @gen_cd_proveedores, @gen_ds_servicio,
					@gen_am_valorprov, @gen_id_monedaprov, @gen_dt_llegada, @gen_dt_salida, @gen_am_pordescuento, @gen_Fecha_Salida, @gen_Fecha_Llegada, @gen_am_basedescuento, @gen_cd_Consecutivo_depende, @gen_cd_Consecutivo_variablesadicionales, @gen_id_referencia_origen;
			
				
				WHILE @@FETCH_STATUS = 0
				BEGIN
					IF @gen_tipo_item = 'TKT'
					BEGIN
						-- Build cargos / impuestos SQL
						SET @TktSqlStmt = '';
						
						DELETE FROM #TmpVariablesObtenidas;
						IF @gen_id_referencia_origen IS NOT NULL
						BEGIN
							INSERT INTO #TmpVariablesObtenidas
							EXEC dbo.spza_ConfiguracionVariablesJOB_ObtenerValores 
								@id_usuario = 1, 
								@id_ReservaGDS_Detalles = @gen_id_referencia_origen;
								
							DECLARE @var_Iden_Variable INT, @var_IDEN_Maestro INT, @var_ValorObtenido VARCHAR(MAX);
							DECLARE curVars CURSOR LOCAL FAST_FORWARD FOR
							SELECT Iden_Variable, IDEN_Maestro, ValorObtenido FROM #TmpVariablesObtenidas WHERE ISNULL(ValorObtenido, '') <> '';

							OPEN curVars;
							FETCH NEXT FROM curVars INTO @var_Iden_Variable, @var_IDEN_Maestro, @var_ValorObtenido;
							WHILE @@FETCH_STATUS = 0
							BEGIN
								SET @TktSqlStmt = @TktSqlStmt + ' INSERT INTO dbo.VariableDatosMaestro (Iden_Variable, IDEN_Maestro, cd_maestro, ValorObtenido) VALUES (' + CAST(@var_Iden_Variable AS VARCHAR) + ', ' + CAST(@var_IDEN_Maestro AS VARCHAR) + ', ''' + REPLACE(@gen_cd_tiquete, '''', '''''') + ''', ''' + REPLACE(@var_ValorObtenido, '''', '''''') + ''');' + CHAR(13) + CHAR(10)
								FETCH NEXT FROM curVars INTO @var_Iden_Variable, @var_IDEN_Maestro, @var_ValorObtenido;
							END;
							CLOSE curVars;
							DEALLOCATE curVars;
						END
						
						DECLARE @c_codigo VARCHAR(20), @ds_nombre VARCHAR(100), @cd_tipo CHAR(1), @am_porcentaje NUMERIC(8,4), @am_valor MONEY, @am_contado MONEY, @am_credito MONEY, @id_carg INT, @id_imp INT;
						
						DECLARE @TktImpuestosSqlStmt VARCHAR(MAX) = '';
						
						-- First Pass: accumulate taxes
						DECLARE curItemTaxes CURSOR LOCAL FAST_FORWARD FOR
						SELECT cd_codigo, ds_nombre, cd_tipo, am_porcentaje, am_valor, am_contado, am_credito, id_carg, id_imp
						FROM #TmpFacturaCargos
						WHERE id_item = @gen_id_item AND cd_tipo IN ('I','R');

						OPEN curItemTaxes;
						FETCH NEXT FROM curItemTaxes INTO @c_codigo, @ds_nombre, @cd_tipo, @am_porcentaje, @am_valor, @am_contado, @am_credito, @id_carg, @id_imp;
						WHILE @@FETCH_STATUS = 0
						BEGIN
							SET @TktImpuestosSqlStmt = @TktImpuestosSqlStmt + CHAR(13) + CHAR(10) + ' EXECUTE dbo.spza_TiqueteImpuestos_Insertar @id_tiquetecargos = @NewCargId, @id_impret = ' + CAST(ISNULL(@id_imp, 1) AS VARCHAR) + ', @ds_impas = ''' + REPLACE(@ds_nombre, '''', '''''') + ''', @am_valor = ' + CAST(@am_valor AS VARCHAR) + ', @am_contado = ' + CAST(@am_contado AS VARCHAR) + ', @am_credito = ' + CAST(@am_credito AS VARCHAR) + ', @am_porcentaje = ' + CAST(@am_porcentaje AS VARCHAR) + ', @id_monedas_iata = @id_monedas_iata, @Tcambio = @Tcambio, @bl_contabilizar=1;'  
							FETCH NEXT FROM curItemTaxes INTO @c_codigo, @ds_nombre, @cd_tipo, @am_porcentaje, @am_valor, @am_contado, @am_credito, @id_carg, @id_imp;
						END
						CLOSE curItemTaxes;
						DEALLOCATE curItemTaxes;

						-- Second Pass: cargos
						DECLARE @HasTktTarCargo BIT = 0;
						IF EXISTS (SELECT 1 FROM #TmpFacturaCargos WHERE id_item = @gen_id_item AND cd_tipo IN ('C','D') AND cd_codigo = 'TAR')
						BEGIN
							SET @HasTktTarCargo = 1;
						END

						DECLARE @IsFirstTktCargo BIT = 1;

						DECLARE curItemCargos CURSOR LOCAL FAST_FORWARD FOR
						SELECT cd_codigo, ds_nombre, cd_tipo, am_porcentaje, am_valor, am_contado, am_credito, id_carg, id_imp
						FROM #TmpFacturaCargos
						WHERE id_item = @gen_id_item AND cd_tipo IN ('C','D');

						OPEN curItemCargos;
						FETCH NEXT FROM curItemCargos INTO @c_codigo, @ds_nombre, @cd_tipo, @am_porcentaje, @am_valor, @am_contado, @am_credito, @id_carg, @id_imp;
						WHILE @@FETCH_STATUS = 0
						BEGIN
							IF (@HasTktTarCargo = 1 AND @c_codigo = 'TAR') OR (@HasTktTarCargo = 0 AND @IsFirstTktCargo = 1)
							BEGIN
								SET @TktSqlStmt = @TktSqlStmt + CHAR(13) + CHAR(10) + ' EXECUTE dbo.spza_TiqueteCargos_Insertar @id_fac_remision = @NewRmId, @id_fac_factura = @NewFacId, @id_tiquetes = @NewTktId, @id_cargosdesc = ' + CAST(ISNULL(@id_carg, 1) AS VARCHAR) + ', @ds_cargonm = ''' + REPLACE(@ds_nombre, '''', '''''') + ''', @am_valor = ' + CAST(@am_valor AS VARCHAR) + ', @am_contado = ' + CAST(@am_contado AS VARCHAR) + ', @am_credito = ' + CAST(@am_credito AS VARCHAR) + ', @bl_noshow = 0, @id_monedas_iata = @id_monedas_iata, @Tcambio = @Tcambio, @SqlStmt = ''' + REPLACE(@TktImpuestosSqlStmt, '''', '''''') + ''';'  
								SET @IsFirstTktCargo = 0;
							END
							ELSE
							BEGIN
								SET @TktSqlStmt = @TktSqlStmt + CHAR(13) + CHAR(10) + ' EXECUTE dbo.spza_TiqueteCargos_Insertar @id_fac_remision = @NewRmId, @id_fac_factura = @NewFacId, @id_tiquetes = @NewTktId, @id_cargosdesc = ' + CAST(ISNULL(@id_carg, 1) AS VARCHAR) + ', @ds_cargonm = ''' + REPLACE(@ds_nombre, '''', '''''') + ''', @am_valor = ' + CAST(@am_valor AS VARCHAR) + ', @am_contado = ' + CAST(@am_contado AS VARCHAR) + ', @am_credito = ' + CAST(@am_credito AS VARCHAR) + ', @bl_noshow = 0, @id_monedas_iata = @id_monedas_iata, @Tcambio = @Tcambio, @SqlStmt = N'''';' 
							END
							FETCH NEXT FROM curItemCargos INTO @c_codigo, @ds_nombre, @cd_tipo, @am_porcentaje, @am_valor, @am_contado, @am_credito, @id_carg, @id_imp;
						END
						CLOSE curItemCargos;
						DEALLOCATE curItemCargos;
						
						--IF @IsFirstTktCargo = 1 AND LTRIM(RTRIM(@TktTarifaSqlStmt)) <> ''
						--BEGIN
						--	SET @TktSqlStmt = @TktSqlStmt + @TktTarifaSqlStmt;
						--END

						-- Build Formas de Pago SQL
						DECLARE @fp_id_fp INT, @fp_id_tc INT, @fp_cd_codigo VARCHAR(10), @fp_ds_nombre VARCHAR(50), @fp_ds_numerotarjeta VARCHAR(50), @fp_ds_vouchertarjeta VARCHAR(50), @fp_ds_expiraciontarjeta VARCHAR(10), @fp_ds_autorizaciontarjeta VARCHAR(50), @fp_in_cuotas INT, @fp_am_valor MONEY;
						DECLARE curItemFPs CURSOR LOCAL FAST_FORWARD FOR
						SELECT id_formaspago, id_tarjetascredito, cd_codigo, ds_nombre, ds_numerotarjeta, ds_vouchertarjeta, ds_expiraciontarjeta, ds_autorizaciontarjeta, in_cuotas, am_valor
						FROM #TmpFacturaFormasPago
						WHERE id_item = @gen_id_item;

						OPEN curItemFPs;
						FETCH NEXT FROM curItemFPs INTO @fp_id_fp, @fp_id_tc, @fp_cd_codigo, @fp_ds_nombre, @fp_ds_numerotarjeta, @fp_ds_vouchertarjeta, @fp_ds_expiraciontarjeta, @fp_ds_autorizaciontarjeta, @fp_in_cuotas, @fp_am_valor;
						WHILE @@FETCH_STATUS = 0
						BEGIN
							SET @TktSqlStmt = @TktSqlStmt + CHAR(13) + CHAR(10) + ' EXECUTE dbo.spza_TiqueteFormasPago_Insertar @id_tiquetes = @NewTktId, @id_fac_factura = @NewFacId, @id_fac_remision = @NewRmId, @id_FormasPago = ' + CAST(@fp_id_fp AS VARCHAR) + ', @ds_fpnm = ''' + REPLACE(@fp_ds_nombre, '''', '''''') + ''', @bl_fprepresenta = 0, @id_TarjetasCredito = ' + ISNULL(CAST(@fp_id_tc AS VARCHAR), 'NULL') + ', @cd_tccode = ' + ISNULL('''' + @fp_cd_codigo + '''', 'NULL') + ', @ds_tcnumber = ' + ISNULL('''' + @fp_ds_numerotarjeta + '''', 'NULL') + ', @ds_tcvoucher = ' + ISNULL('''' + @fp_ds_vouchertarjeta + '''', 'NULL') + ', @ds_tcexp = ' + ISNULL('''' + @fp_ds_expiraciontarjeta + '''', 'NULL') + ', @cd_idbanco = NULL, @ds_cheque = NULL, @ds_plaza = NULL, @ds_referencia = NULL, @ds_poliza = NULL, @ds_polanexo = NULL, @am_valor = ' + CAST(@fp_am_valor AS VARCHAR) + ', @id_monedas_iata = @id_monedas_iata, @Tcambio = @Tcambio, @ds_tcautorizacion = ' + ISNULL('''' + @fp_ds_autorizaciontarjeta + '''', 'NULL') + ', @in_tccuotas = ' + CAST(@fp_in_cuotas AS VARCHAR) + ';' 
							FETCH NEXT FROM curItemFPs INTO @fp_id_fp, @fp_id_tc, @fp_cd_codigo, @fp_ds_nombre, @fp_ds_numerotarjeta, @fp_ds_vouchertarjeta, @fp_ds_expiraciontarjeta, @fp_ds_autorizaciontarjeta, @fp_in_cuotas, @fp_am_valor;
						END
						CLOSE curItemFPs;
						DEALLOCATE curItemFPs;

						-- Build Itinerarios SQL (inline query, no temp table needed)
						SET @TktItinSqlStmt = '';
						SELECT 
							@TktItinSqlStmt = @TktItinSqlStmt + + CHAR(13) + CHAR(10) + 
							'EXECUTE dbo.spza_TiqueteItinerarios_Insertar 
								@id_fac_factura = @NewFacId, 
								@id_fac_remision = @NewRmId, 
								@id_Tiquetes = @NewTktId, 
								@orden = ' + CAST(orden AS VARCHAR) + ', 
								@cd_origen = ''' + ISNULL(cd_origen,'') + ''', 
								@cd_destino = ''' + ISNULL(cd_destino,'') + ''', 
								@cd_clase = ''' + ISNULL(cd_clase,'') + ''', 
								@fecha_salida = ''' + ISNULL(CONVERT(VARCHAR(10),fecha_salida,111),'') + ''', 
								@hora_salida = ''' + ISNULL(hora_salida,'') + ''', 
								@hora_llegada = ''' + ISNULL(hora_llegada,'') + ''', 
								@terminal = ''' + REPLACE(ISNULL(terminal,''), '''', '''''') + ''', 
								@cd_aero_siglas = ''' + ISNULL(cd_aero_siglas,'') + ''', 
								@cd_farebasis = ''' + ISNULL(cd_farebasis,'') + ''', 
								@ds_NumVuelo = ''' + ISNULL(ds_NumVuelo,'') + ''', 
								@ds_TipoVuelo = ''' + ISNULL(ds_TipoVuelo,'') + ''', 
								@am_valor = ' + CAST(ISNULL(am_valor, 0) AS VARCHAR) + ', 
								@bl_NoUtilizado = NULL, 
								@am_co2 = ' + CAST(ISNULL(am_co2, 0) AS VARCHAR) + '; '
						FROM dbo.ReservaGDS_Itinerarios
						WHERE id_reserva = @gen_id_air
						ORDER BY Orden;

						SET @SqlStmt = @SqlStmt + CHAR(13) + CHAR(10) + '
						DECLARE @NewTktId_' + CAST(@ItemIndex AS VARCHAR) + ' INT;
						EXECUTE dbo.spza_Tiquete_Vender
							@cd_tiquete = ''' + @gen_cd_tiquete + ''',
							@id_TiposDocumento = ' + CAST(@gen_id_TiposDocumento AS VARCHAR) + ',
							@id_entdist = ' + CAST(@gen_id_entdist AS VARCHAR) + ',
							@in_estado = 1,
							@in_nacionalidad = ' + CAST(@gen_in_nacionalidad AS VARCHAR) + ',
							@id_entvend = ' + CAST(@gen_id_entvend AS VARCHAR) + ',
							@id_fac_factura = @NewFacId,
							@id_fac_remision = @NewRmId,
							@cd_tktrevisado = ' + ISNULL('''' + @gen_cd_tktrevisado + '''', 'NULL') + ',
							@id_pax = NULL,
							@ds_paxname = ''' + @gen_ds_paxname + ''',
							@ds_paxape = ''' + @gen_ds_paxape + ''',
							@ds_paxprefix = ''' + ISNULL(@gen_ds_paxprefix, '') + ''',
							@cd_paxcedula = ''' + ISNULL(@gen_cd_pax_CC, '') + ''',
							@ds_itinerario = ''' + LEFT(@gen_ds_itinerario, 63) + ''',
							@ds_itinerarioaerolinea = ''' + LEFT(ISNULL(@gen_ds_itinerarioaerolinea, ''), 63) + ''',
							@ds_clases = ''' + ISNULL(@gen_ds_clases, '') + ''',
							@dt_fechasalida = ' + ISNULL('''' + CONVERT(VARCHAR, @gen_Fecha_Salida, 120) + '''', 'NULL') + ',
							@dt_fechallegada = ' + ISNULL('''' + CONVERT(VARCHAR, @gen_Fecha_Llegada, 120) + '''', 'NULL') + ',
							@cd_destino = ''' + ISNULL(@gen_cd_destino, '') + ''',
							@dt_fechaexped = ''' + CONVERT(VARCHAR, @gen_dt_fechaexped, 120) + ''',
							@id_usuario = 1,
							@id_tiqueteadores = ' + CAST(@gen_id_tiqueteadores AS VARCHAR) + ',
							@am_hf = ' + CAST(@gen_am_highfare AS VARCHAR) + ',
							@am_lf = ' + CAST(@gen_am_lowfare AS VARCHAR) + ',
							@am_tarifa = ' + CAST(@gen_am_tarifa AS VARCHAR) + ',
							@cd_ah = ''' + ISNULL(@gen_cd_tourcode, '') + ''',
							@am_desah = 0,
							@id_gds = ' + CAST(@gen_id_gds AS VARCHAR) + ',
							@iden_gds = ' + CAST(@gen_iden_gds AS VARCHAR) + ',
							@in_numtktconj = ' + CAST(@gen_NumTktConj AS VARCHAR) + ',
							@bl_NoCalcComision = 0,
							@bl_NoCalcIvaComision = 0,
							@am_comisionPNR = ' + CAST(@gen_am_Comision AS VARCHAR) + ',
							@am_basecomisionable = ' + CAST(@gen_am_tarifa AS VARCHAR) + ',
							@am_porcomision = 0,
							@ds_records = ''' + @gen_ds_records + ''',
							@id_hotel = NULL,
							@id_precompra = ' + ISNULL(CAST(@gen_Id_Precompra AS VARCHAR), 'NULL') + ',
							@id_TipoTiquete = NULL,
							@id_ReassonCode = NULL,
							@cencosto_interno = ''' + ISNULL(@gen_cd_cencosto, '') + ''',
							@ds_solicita = ''' + ISNULL(@gen_ds_solicita, '') + ''',
							@ds_lapsoviaje = ''' + ISNULL(@gen_ds_lapsoviaje, '') + ''',
							@id_monedas_iata = @id_monedas_iata,
							@Tcambio = @Tcambio,
							@cd_TiqueteGr = NULL,
							@SqlStmt = ''' + REPLACE(@TktSqlStmt, '''', '''''') + ''',
							@SqlStmtItinerarios = ''' + REPLACE(@TktItinSqlStmt, '''', '''''') + ''',
							@id_sucursal = @id_sucursal,
							@id_implante = @id_implante,
							@bl_ahorro = ' + CAST(@gen_bl_ahorro AS VARCHAR) + ',
							@cd_TipoTiqueteGDS = ''' + ISNULL(@gen_cd_TipoTiqueteGDS, '') + ''',
							@cd_tourcode = ''' + ISNULL(@gen_cd_tourcode, '') + ''',
							@cd_PasaportePax = ''' + ISNULL(@gen_cd_PasaportePax, '') + ''',
							@am_valor_aerolinea = ' + CAST(@gen_am_tarifa AS VARCHAR) + ',
							@am_porcentaje_comision_BackEnd = 0,
							@am_valor_comision_BackEnd = 0,
							@am_PorFacParcial = ' + CAST(ISNULL(@gen_am_PorFacParcial, 100) AS VARCHAR) + ',
							@in_cantpax = ' + CAST(ISNULL(@gen_in_cantpax, 1) AS VARCHAR) + ',
							@OrdenGrabacion = ' + CAST(ISNULL(@ItemIndex, 1) AS VARCHAR) + ',
							@cd_Penalidad = NULL,
							@id_entdistIata = NULL,
							@id_entvendIata = NULL; ';
					END
					ELSE IF @gen_tipo_item = 'TAO'
					BEGIN
						-- Build cargos / impuestos SQL
						SET @TaoCargSqlStmt = '';
						
						DECLARE @tc_codigo VARCHAR(20), @tc_ds_nombre VARCHAR(100), @tc_cd_tipo CHAR(1), @tc_am_porcentaje NUMERIC(8,4), @tc_am_valor MONEY, @tc_am_contado MONEY, @tc_am_credito MONEY, @tc_id_carg INT, @tc_id_imp INT;
						
						DECLARE @TaoImpuestosSqlStmt VARCHAR(MAX) = '';
						
						-- First Pass: accumulate taxes
						DECLARE curItemTaoTaxes CURSOR LOCAL FAST_FORWARD FOR
						SELECT cd_codigo, ds_nombre, cd_tipo, am_porcentaje, am_valor, am_contado, am_credito, id_carg, id_imp
						FROM #TmpFacturaCargos
						WHERE id_item = @gen_id_item AND cd_tipo IN ('I','R');

						OPEN curItemTaoTaxes;
						FETCH NEXT FROM curItemTaoTaxes INTO @tc_codigo, @tc_ds_nombre, @tc_cd_tipo, @tc_am_porcentaje, @tc_am_valor, @tc_am_contado, @tc_am_credito, @tc_id_carg, @tc_id_imp;
						WHILE @@FETCH_STATUS = 0
						BEGIN
							SET @TaoImpuestosSqlStmt = @TaoImpuestosSqlStmt + CHAR(13) + CHAR(10) + ' EXECUTE dbo.spza_TaoImpuestos_Insertar @id_FacTaoCargos = @NewCargId, @id_impret = ' + CAST(ISNULL(@tc_id_imp, 1) AS VARCHAR) + ', @ds_impas = ''' + REPLACE(@tc_ds_nombre, '''', '''''') + ''', @am_valor = ' + CAST(@tc_am_valor AS VARCHAR) + ', @am_contado = ' + CAST(@tc_am_contado AS VARCHAR) + ', @am_credito = ' + CAST(@tc_am_credito AS VARCHAR) + ', @am_porcentaje=' + CAST(@tc_am_porcentaje AS VARCHAR) + ', @id_monedas_iata = @id_monedas_iata, @Tcambio = @Tcambio, @bl_contabilizar=1;' 
							FETCH NEXT FROM curItemTaoTaxes INTO @tc_codigo, @tc_ds_nombre, @tc_cd_tipo, @tc_am_porcentaje, @tc_am_valor, @tc_am_contado, @tc_am_credito, @tc_id_carg, @tc_id_imp;
						END
						CLOSE curItemTaoTaxes;
						DEALLOCATE curItemTaoTaxes;

						-- Second Pass: cargos
						DECLARE @HasTaoTarCargo BIT = 0;
						IF EXISTS (SELECT 1 FROM #TmpFacturaCargos WHERE id_item = @gen_id_item AND cd_tipo IN ('C','D') AND cd_codigo = 'TAR')
						BEGIN
							SET @HasTaoTarCargo = 1;
						END

						DECLARE @IsFirstTaoCargo BIT = 1;

						DECLARE curItemTaoCargos CURSOR LOCAL FAST_FORWARD FOR
						SELECT cd_codigo, ds_nombre, cd_tipo, am_porcentaje, am_valor, am_contado, am_credito, id_carg, id_imp
						FROM #TmpFacturaCargos
						WHERE id_item = @gen_id_item AND cd_tipo IN ('C','D');

						OPEN curItemTaoCargos;
						FETCH NEXT FROM curItemTaoCargos INTO @tc_codigo, @tc_ds_nombre, @tc_cd_tipo, @tc_am_porcentaje, @tc_am_valor, @tc_am_contado, @tc_am_credito, @tc_id_carg, @tc_id_imp;
						WHILE @@FETCH_STATUS = 0
						BEGIN
							IF (@HasTaoTarCargo = 1 AND @tc_codigo = 'TAR') OR (@HasTaoTarCargo = 0 AND @IsFirstTaoCargo = 1)
							BEGIN
								SET @TaoCargSqlStmt = @TaoCargSqlStmt + CHAR(13) + CHAR(10) + ' EXECUTE dbo.spza_TaoCargos_Insertar @id_fac_remision = @NewRmId, @id_fac_factura = @NewFacId, @Id_Fac_Tao = @NewTaoId, @id_cargosdesc = ' + CAST(ISNULL(@tc_id_carg, 1) AS VARCHAR) + ', @ds_cargonm = ''' + REPLACE(@tc_ds_nombre, '''', '''''') + ''', @am_valor = ' + CAST(@tc_am_valor AS VARCHAR) + ', @am_contado = ' + CAST(@tc_am_contado AS VARCHAR) + ', @am_credito = ' + CAST(@tc_am_credito AS VARCHAR) + ', @bl_noshow = 0, @id_monedas_iata = @id_monedas_iata, @Tcambio = @Tcambio, @SqlStmt = ''' + REPLACE(@TaoImpuestosSqlStmt, '''', '''''') + ''';' 
								SET @IsFirstTaoCargo = 0;
							END
							ELSE
							BEGIN
								SET @TaoCargSqlStmt = @TaoCargSqlStmt + CHAR(13) + CHAR(10) + ' EXECUTE dbo.spza_TaoCargos_Insertar @id_fac_remision = @NewRmId, @id_fac_factura = @NewFacId, @Id_Fac_Tao = @NewTaoId, @id_cargosdesc = ' + CAST(ISNULL(@tc_id_carg, 1) AS VARCHAR) + ', @ds_cargonm = ''' + REPLACE(@tc_ds_nombre, '''', '''''') + ''', @am_valor = ' + CAST(@tc_am_valor AS VARCHAR) + ', @am_contado = ' + CAST(@tc_am_contado AS VARCHAR) + ', @am_credito = ' + CAST(@tc_am_credito AS VARCHAR) + ', @bl_noshow = 0, @id_monedas_iata = @id_monedas_iata, @Tcambio = @Tcambio, @SqlStmt = N'''';' 
							END
							FETCH NEXT FROM curItemTaoCargos INTO @tc_codigo, @tc_ds_nombre, @tc_cd_tipo, @tc_am_porcentaje, @tc_am_valor, @tc_am_contado, @tc_am_credito, @tc_id_carg, @tc_id_imp;
						END
						CLOSE curItemTaoCargos;
						DEALLOCATE curItemTaoCargos;
						
						--IF @IsFirstTaoCargo = 1 AND LTRIM(RTRIM(@TaoImpuestosSqlStmt)) <> ''
						--BEGIN
						--	SET @TaoCargSqlStmt = @TaoCargSqlStmt + @TaoTarifaSqlStmt;
						--END

						-- Build Formas de Pago SQL
						SET @TaoFpSqlStmt = '';
						
						DECLARE @tfp_id_fp INT, @tfp_id_tc INT, @tfp_cd_codigo VARCHAR(10), @tfp_ds_nombre VARCHAR(50), @tfp_ds_numerotarjeta VARCHAR(50), @tfp_ds_vouchertarjeta VARCHAR(50), @tfp_ds_expiraciontarjeta VARCHAR(10), @tfp_ds_autorizaciontarjeta VARCHAR(50), @tfp_in_cuotas INT, @tfp_am_valor MONEY;
						DECLARE curItemTaoFPs CURSOR LOCAL FAST_FORWARD FOR
						SELECT id_formaspago, id_tarjetascredito, cd_codigo, ds_nombre, ds_numerotarjeta, ds_vouchertarjeta, ds_expiraciontarjeta, ds_autorizaciontarjeta, in_cuotas, am_valor
						FROM #TmpFacturaFormasPago
						WHERE id_item = @gen_id_item;

						OPEN curItemTaoFPs;
						FETCH NEXT FROM curItemTaoFPs INTO @tfp_id_fp, @tfp_id_tc, @tfp_cd_codigo, @tfp_ds_nombre, @tfp_ds_numerotarjeta, @tfp_ds_vouchertarjeta, @tfp_ds_expiraciontarjeta, @tfp_ds_autorizaciontarjeta, @tfp_in_cuotas, @tfp_am_valor;
						WHILE @@FETCH_STATUS = 0
						BEGIN
							SET @TaoFpSqlStmt = @TaoFpSqlStmt + CHAR(13) + CHAR(10) + ' EXECUTE dbo.spza_TaoFormasPago_Insertar @Id_Fac_Tao = @NewTaoId, @id_fac_factura = @NewFacId, @id_fac_remision = @NewRmId, @id_formaspago = ' + CAST(@tfp_id_fp AS VARCHAR) + ', @ds_fpnm = ''' + REPLACE(@tfp_ds_nombre, '''', '''''') + ''', @bl_fprepresenta = 0, @id_tarjetascredito = ' + ISNULL(CAST(@tfp_id_tc AS VARCHAR), 'NULL') + ', @cd_tccode = ' + ISNULL('''' + @tfp_cd_codigo + '''', 'NULL') + ', @ds_tcnumber = ' + ISNULL('''' + @tfp_ds_numerotarjeta + '''', 'NULL') + ', @ds_tcvoucher = NULL, @ds_tcexp = NULL, @cd_idbanco = NULL, @ds_cheque = NULL, @ds_plaza = NULL, @ds_referencia = NULL, @ds_poliza = NULL, @ds_polanexo = NULL, @am_valor = ' + CAST(@tfp_am_valor AS VARCHAR) + ', @id_monedas_iata = @id_monedas_iata, @Tcambio = @Tcambio, @ds_tcautorizacion = NULL, @in_tccuotas = 0;' 
							FETCH NEXT FROM curItemTaoFPs INTO @tfp_id_fp, @tfp_id_tc, @tfp_cd_codigo, @tfp_ds_nombre, @tfp_ds_numerotarjeta, @tfp_ds_vouchertarjeta, @tfp_ds_expiraciontarjeta, @tfp_ds_autorizaciontarjeta, @tfp_in_cuotas, @tfp_am_valor;
						END
						CLOSE curItemTaoFPs;
						DEALLOCATE curItemTaoFPs;

						SET @SqlStmt = @SqlStmt + CHAR(13) + CHAR(10) +'
						DECLARE @NewTaoId_' + CAST(@ItemIndex AS VARCHAR) + ' INT;
						EXECUTE dbo.spza_Tao_Vender
							@cd_tiquete = ''' + @gen_cd_tiquete + ''',
							@ds_descrip = ''' + ISNULL(@gen_ds_descrip, '') + ''',
							@id_fac_factura = @NewFacId,
							@id_fac_remision = @NewRmId,
							@in_nacionalidad = ' + CAST(@gen_in_nacionalidad AS VARCHAR) + ',
							@cd_cencosto = ''' + ISNULL(@gen_cd_cencosto, '') + ''',
							@cd_aux = ''' + ISNULL(@gen_cd_auxiliar, '') + ''',
							@cd_coditem = ''' + ISNULL(@gen_cd_item, '') + ''',
							@am_basecomisionable = ' + CAST(@gen_am_tarifa AS VARCHAR) + ',
							@am_porcomision = 0,
							@id_monedas_iata = @id_monedas_iata,
							@Tcambio = @Tcambio,
							@OrdenGrabacion = ' + CAST(@ItemIndex AS VARCHAR) + ',
							@SqlStmt = ''' + REPLACE(@TaoCargSqlStmt + @TaoFpSqlStmt, '''', '''''') + '''; '
					END
					ELSE IF @gen_tipo_item = 'SRV'
					BEGIN
						-- Build cargos / impuestos / provider / pax SQL
						SET @SrvSqlStmt = '';
						SET @SrvImpuestosSqlStmt = '';
						
						DELETE FROM #TmpVariablesObtenidas;
						IF @gen_id_referencia_origen IS NOT NULL
						BEGIN
							INSERT INTO #TmpVariablesObtenidas
							EXEC dbo.spza_ConfiguracionVariablesJOB_ObtenerValores 
								@id_usuario = 1, 
								@id_ReservaGDS_Servicios = @gen_id_referencia_origen;

							DECLARE @var_Iden_Variable_srv INT, @var_IDEN_Maestro_srv INT, @var_ValorObtenido_srv VARCHAR(MAX);
							DECLARE curVarsSrv CURSOR LOCAL FAST_FORWARD FOR
							SELECT Iden_Variable, IDEN_Maestro, ValorObtenido FROM #TmpVariablesObtenidas WHERE ISNULL(ValorObtenido, '') <> '';

							OPEN curVarsSrv;
							FETCH NEXT FROM curVarsSrv INTO @var_Iden_Variable_srv, @var_IDEN_Maestro_srv, @var_ValorObtenido_srv;
							WHILE @@FETCH_STATUS = 0
							BEGIN
								SET @SrvSqlStmt = @SrvSqlStmt +CHAR(13) + CHAR(10)+ ' INSERT INTO dbo.VariableDatosMaestro (Iden_Variable, IDEN_Maestro, cd_maestro, ValorObtenido) VALUES (' + CAST(@var_Iden_Variable_srv AS VARCHAR) + ', ' + CAST(@var_IDEN_Maestro_srv AS VARCHAR) + ', ''' + REPLACE(@gen_cd_Consecutivo_variablesadicionales, '''', '''''') + ''', ''' + REPLACE(@var_ValorObtenido_srv, '''', '''''') + ''');' 
								FETCH NEXT FROM curVarsSrv INTO @var_Iden_Variable_srv, @var_IDEN_Maestro_srv, @var_ValorObtenido_srv;
							END;
							CLOSE curVarsSrv;
							DEALLOCATE curVarsSrv;
						END
						SET @SrvCargSqlStmt = '';
						SET @SrvFpSqlStmt = '';

						DECLARE @sc_codigo VARCHAR(20), @sc_ds_nombre VARCHAR(100), @sc_cd_tipo CHAR(1), @sc_am_porcentaje NUMERIC(8,4), @sc_am_valor MONEY, @sc_am_contado MONEY, @sc_am_credito MONEY, @sc_id_carg INT, @sc_id_imp INT;
						DECLARE @HasTarCargo BIT, @IsFirstCargo BIT;
						
						-- First Pass: accumulate service taxes (impuestos/retenciones)
						DECLARE curItemSrvTaxes CURSOR LOCAL FAST_FORWARD FOR
						SELECT cd_codigo, ds_nombre, cd_tipo, am_porcentaje, am_valor, am_contado, am_credito, id_carg, id_imp
						FROM #TmpFacturaCargos
						WHERE id_item = @gen_id_item AND cd_tipo IN ('I','R');

						OPEN curItemSrvTaxes;
						FETCH NEXT FROM curItemSrvTaxes INTO @sc_codigo, @sc_ds_nombre, @sc_cd_tipo, @sc_am_porcentaje, @sc_am_valor, @sc_am_contado, @sc_am_credito, @sc_id_carg, @sc_id_imp;
						WHILE @@FETCH_STATUS = 0
						BEGIN
							SET @SrvImpuestosSqlStmt = @SrvImpuestosSqlStmt + CHAR(13) + CHAR(10) + ' EXECUTE dbo.spza_ServicioImpuestos_Insertar @id_FacServiciosCargos = @NewCargId, @id_impret = ' + CAST(ISNULL(@sc_id_imp, 1) AS VARCHAR) + ', @ds_impas = ''' + REPLACE(@sc_ds_nombre, '''', '''''') + ''', @cd_impcta = '''', @am_valor = ' + CAST(@sc_am_valor AS VARCHAR) + ', @am_contado = ' + CAST(@sc_am_contado AS VARCHAR) + ', @am_credito = ' + CAST(@sc_am_credito AS VARCHAR) + ', @am_porcentaje = ' + CAST(@sc_am_porcentaje AS VARCHAR) + ', @id_monedas_iata = @id_monedas_iata, @Tcambio = @Tcambio, @bl_contabilizar = 1, @am_deltaCorreccion = 0;' 
							FETCH NEXT FROM curItemSrvTaxes INTO @sc_codigo, @sc_ds_nombre, @sc_cd_tipo, @sc_am_porcentaje, @sc_am_valor, @sc_am_contado, @sc_am_credito, @sc_id_carg, @sc_id_imp;
						END
						CLOSE curItemSrvTaxes;
						DEALLOCATE curItemSrvTaxes;

						-- Second Pass: process cargos and link accumulated taxes to 'TAR' or first cargo
						DECLARE curItemSrvCargos CURSOR LOCAL FAST_FORWARD FOR
						SELECT cd_codigo, ds_nombre, cd_tipo, am_porcentaje, am_valor, am_contado, am_credito, id_carg, id_imp
						FROM #TmpFacturaCargos
						WHERE id_item = @gen_id_item AND cd_tipo IN ('C','D');

						SET @HasTarCargo = 0;
						IF EXISTS (SELECT 1 FROM #TmpFacturaCargos WHERE id_item = @gen_id_item AND cd_tipo IN ('C','D') AND cd_codigo = 'TAR')
						BEGIN
							SET @HasTarCargo = 1;
						END

						SET @IsFirstCargo = 1;

						OPEN curItemSrvCargos;
						FETCH NEXT FROM curItemSrvCargos INTO @sc_codigo, @sc_ds_nombre, @sc_cd_tipo, @sc_am_porcentaje, @sc_am_valor, @sc_am_contado, @sc_am_credito, @sc_id_carg, @sc_id_imp;
						WHILE @@FETCH_STATUS = 0
						BEGIN
							IF (@HasTarCargo = 1 AND @sc_codigo = 'TAR') OR (@HasTarCargo = 0 AND @IsFirstCargo = 1)
							BEGIN
								SET @SrvCargSqlStmt = @SrvCargSqlStmt + CHAR(13) + CHAR(10) + ' EXECUTE dbo.spza_ServicioCargos_Insertar @id_Fac_Servicios = @NewSrvId, @id_cargosdesc = ' + CAST(ISNULL(@sc_id_carg, 1) AS VARCHAR) + ', @ds_cargonm = ''' + REPLACE(@sc_ds_nombre, '''', '''''') + ''', @am_valor = ' + CAST(@sc_am_valor AS VARCHAR) + ', @am_contado = ' + CAST(@sc_am_contado AS VARCHAR) + ', @am_credito = ' + CAST(@sc_am_credito AS VARCHAR) + ', @bl_noshow = 0, @id_monedas_iata = @id_monedas_iata, @Tcambio = @Tcambio, @SqlStmt = ''' + REPLACE(@SrvImpuestosSqlStmt, '''', '''''') + ''';' 
								SET @IsFirstCargo = 0;
							END
							ELSE
							BEGIN
								SET @SrvCargSqlStmt = @SrvCargSqlStmt + CHAR(13) + CHAR(10) + ' EXECUTE dbo.spza_ServicioCargos_Insertar @id_Fac_Servicios = @NewSrvId, @id_cargosdesc = ' + CAST(ISNULL(@sc_id_carg, 1) AS VARCHAR) + ', @ds_cargonm = ''' + REPLACE(@sc_ds_nombre, '''', '''''') + ''', @am_valor = ' + CAST(@sc_am_valor AS VARCHAR) + ', @am_contado = ' + CAST(@sc_am_contado AS VARCHAR) + ', @am_credito = ' + CAST(@sc_am_credito AS VARCHAR) + ', @bl_noshow = 0, @id_monedas_iata = @id_monedas_iata, @Tcambio = @Tcambio, @SqlStmt = N'''';' 
							END
							FETCH NEXT FROM curItemSrvCargos INTO @sc_codigo, @sc_ds_nombre, @sc_cd_tipo, @sc_am_porcentaje, @sc_am_valor, @sc_am_contado, @sc_am_credito, @sc_id_carg, @sc_id_imp;
						END
						CLOSE curItemSrvCargos;
						DEALLOCATE curItemSrvCargos;

						-- Build Formas de Pago SQL
						DECLARE @sfp_id_fp INT, @sfp_id_tc INT, @sfp_cd_codigo VARCHAR(10), @sfp_ds_nombre VARCHAR(50), @sfp_ds_numerotarjeta VARCHAR(50), @sfp_ds_vouchertarjeta VARCHAR(50), @sfp_ds_expiraciontarjeta VARCHAR(10), @sfp_ds_autorizaciontarjeta VARCHAR(50), @sfp_in_cuotas INT, @sfp_am_valor MONEY;
						DECLARE curItemSrvFPs CURSOR LOCAL FAST_FORWARD FOR
						SELECT id_formaspago, id_tarjetascredito, cd_codigo, ds_nombre, ds_numerotarjeta, ds_vouchertarjeta, ds_expiraciontarjeta, ds_autorizaciontarjeta, in_cuotas, am_valor
						FROM #TmpFacturaFormasPago
						WHERE id_item = @gen_id_item;

						OPEN curItemSrvFPs;
						FETCH NEXT FROM curItemSrvFPs INTO @sfp_id_fp, @sfp_id_tc, @sfp_cd_codigo, @sfp_ds_nombre, @sfp_ds_numerotarjeta, @sfp_ds_vouchertarjeta, @sfp_ds_expiraciontarjeta, @sfp_ds_autorizaciontarjeta, @sfp_in_cuotas, @sfp_am_valor;
						WHILE @@FETCH_STATUS = 0
						BEGIN
							SET @SrvFpSqlStmt = @SrvFpSqlStmt + CHAR(13) + CHAR(10) +' EXECUTE dbo.spza_ServicioFormasPago_Insertar @id_Fac_Servicios = @NewSrvId, @id_fac_factura = @NewFacId, @id_fac_remision = @NewRmId, @id_formaspago = ' + CAST(@sfp_id_fp AS VARCHAR) + ', @am_valor = ' + CAST(@sfp_am_valor AS VARCHAR) + ', @id_tarjetascredito = ' + ISNULL(CAST(@sfp_id_tc AS VARCHAR), 'NULL') + ', @cd_tccode = NULL, @ds_tcnumber = ' + ISNULL('''' + @sfp_ds_numerotarjeta + '''', 'NULL') + ', @ds_tcvoucher = NULL, @ds_tcexp = NULL, @ds_tcautorizacion = NULL, @in_cuotas = 1, @id_monedas_iata = @id_monedas_iata, @Tcambio = @Tcambio, @ds_fpnm = ''' + REPLACE(@sfp_ds_nombre, '''', '''''') + ''';' 
							FETCH NEXT FROM curItemSrvFPs INTO @sfp_id_fp, @sfp_id_tc, @sfp_cd_codigo, @sfp_ds_nombre, @sfp_ds_numerotarjeta, @sfp_ds_vouchertarjeta, @sfp_ds_expiraciontarjeta, @sfp_ds_autorizaciontarjeta, @sfp_in_cuotas, @sfp_am_valor;
						END
						CLOSE curItemSrvFPs;
						DEALLOCATE curItemSrvFPs;

						-- Build provider SQL
						SET @SrvProvSqlStmt = '';
						DECLARE @c_id_tipoproveedor INT, @c_cd_tipoproveedor VARCHAR(10), @c_ds_tipoproveedor VARCHAR(100);
						IF ISNULL(@gen_cd_proveedores, '') <> ''
						BEGIN
							SELECT TOP 1 
								@c_id_tipoproveedor = tp.id, 
								@c_cd_tipoproveedor = tp.cd_codigo, 
								@c_ds_tipoproveedor = tp.ds_nombre 
							FROM dbo.TipoProveedores tp WITH(NOLOCK) 
							WHERE tp.cd_codigo = 'HTL';
							
							IF @c_id_tipoproveedor IS NOT NULL
							BEGIN
								SET @SrvProvSqlStmt = CHAR(13) + CHAR(10) + ' EXECUTE dbo.spza_ServicioTipoProv_Insertar @id_Fac_Servicios = @NewSrvId, @id_tipoproveedor = ' + CAST(@c_id_tipoproveedor AS VARCHAR) + ', @cd_codigo = ''' + @c_cd_tipoproveedor + ''', @ds_nombre = ''' + REPLACE(@c_ds_tipoproveedor, '''', '''''') + ''';'
							END;
						END;

						-- Build pax SQL
						SET @SrvPaxSqlStmt = '';
						IF ISNULL(@gen_ds_paxname, '') <> ''
						BEGIN
							SET @SrvPaxSqlStmt = CHAR(13) + CHAR(10) + ' EXECUTE dbo.spza_ServicioPaxAdicional_insertar @id_Fac_Servicios = @NewSrvId, @ds_nombre = ''' + REPLACE(@gen_ds_paxname, '''', '''''') + ''', @ds_apellido = ''' + REPLACE(@gen_ds_paxape, '''', '''''') + ''', @in_edad = NULL, @cd_paxtype = ''' + @gen_ds_paxprefix + ''', @ds_paxClasificacion = NULL;'
						END;

						SET @SrvSqlStmt = @SrvCargSqlStmt + @SrvProvSqlStmt + @SrvPaxSqlStmt + @SrvFpSqlStmt;

						SET @SqlStmt = @SqlStmt + CHAR(13) + CHAR(10) + '
						DECLARE @NewSrvId_' + CAST(@ItemIndex AS VARCHAR) + ' INT;
						EXECUTE dbo.spza_Servicio_Vender
							@ds_descrip = ''' + ISNULL(@gen_ds_descrip, '') + ''',
							@id_fac_factura = @NewFacId,
							@id_fac_remision = @NewRmId,
							@id_CotizacionServicios = NULL,
							@in_nacionalidad = ' + CAST(@gen_in_nacionalidad AS VARCHAR) + ',
							@cd_cencosto = ''' + ISNULL(@gen_cd_cencosto, '') + ''',
							@cd_auxiliar = ''' + ISNULL(@gen_cd_auxiliar, '') + ''',
							@cd_item = ''' + ISNULL(@gen_cd_item, '') + ''',
							@id_tiposconceptfac = ' + ISNULL(CAST(@gen_id_tiposconceptfac AS VARCHAR), 'NULL') + ',
							@id_conceptofacturacion = ' + ISNULL(CAST(@gen_id_conceptofacturacion AS VARCHAR), 'NULL') + ',
							@id_tiposservicio = ' + ISNULL(CAST(@gen_id_tiposservicio AS VARCHAR), 'NULL') + ',
							@cd_tiquete = ' + ISNULL('''' + @gen_cd_tiquete + '''', 'NULL') + ',
							@id_voucherstocks = NULL,
							@cd_voucherPrefijo = NULL,
							@cd_proveedores = ''' + ISNULL(@gen_cd_proveedores, '') + ''',
							@ds_tiposervnm = ''' + ISNULL(@gen_ds_servicio, '') + ''',
							@cd_prov_hotel = NULL,
							@cd_prov_car = NULL,
							@cd_prov_air = NULL,
							@ds_servicio = ''' + ISNULL(@gen_ds_servicio, '') + ''',
							@am_valorprov = ' + CAST(@gen_am_tarifa AS VARCHAR) + ',
							@id_monedaprov = ' + ISNULL(CAST(@id_monedas_iata AS VARCHAR), 'NULL') + ',
							@ds_InfoAdicional = NULL,
							@ds_paxname = ''' + ISNULL(@gen_ds_paxname, '') + ''',
							@ds_paxape = ''' + ISNULL(@gen_ds_paxape, '') + ''',
							@cd_paxtype = ''' + ISNULL(@gen_ds_paxprefix, '') + ''',
							@in_edad = NULL,
							@cd_voucher = NULL,
							@in_cantpax = 1,
							@dt_llegada = ' + ISNULL('''' + CONVERT(VARCHAR, @gen_dt_llegada, 120) + '''', 'NULL') + ',
							@dt_salida = ' + ISNULL('''' + CONVERT(VARCHAR, @gen_dt_salida, 120) + '''', 'NULL') + ',
							@ds_destino = NULL,
							@id_gds = NULL,
							@am_basecomisionable = ' + CAST(@gen_am_tarifa AS VARCHAR) + ',
							@am_porcomision = 0,
							@id_tipoplan = NULL,
							@id_acomodacion = NULL,
							@ds_paxClasificacion = NULL,
							@in_dias = NULL,
							@id_monedas_iata = @id_monedas_iata,
							@Tcambio = @Tcambio,
							@Id_GrConcepto = NULL,
							@in_diasSrv = NULL,
							@in_nochesSrv = NULL,
							@OrdenGrabacion = ' + CAST(@ItemIndex AS VARCHAR) + ',
							@Id_Especialista = NULL,
							@am_porcentaje_descuento = ' + CAST(ISNULL(@gen_am_pordescuento, 0) AS VARCHAR) + ',
							@am_valor_descuento = 0,
							@ds_motivo_descuento = NULL,
							@Id_CargosDesc_Descuento = NULL,
							@dt_FechaSalidaSrv = ' + ISNULL('''' + CONVERT(VARCHAR, @gen_dt_llegada, 120) + '''', 'NULL') + ',
							@dt_FechaLlegadaSrv = ' + ISNULL('''' + CONVERT(VARCHAR, @gen_dt_salida, 120) + '''', 'NULL') + ',
							@cd_VoucherPax = NULL,
							@am_basecomisionableprov = ' + CAST(@gen_am_tarifa AS VARCHAR) + ',
							@am_porcomisionprov = 0,
							@cd_NumeFac = NULL,
							@dt_VenceFac = NULL,
							@Id_AcomodacionSrv = NULL,
							@Id_TipoPlanSrv = NULL,
							@in_habitaciones = NULL,
							@in_habitacionesSrv = NULL,
							@SqlStmt = ''' + REPLACE(@SrvSqlStmt, '''', '''''') + ''',
							@cd_Consecutivo_variablesadicionales = ' + ISNULL('''' + @gen_cd_Consecutivo_variablesadicionales + '''', 'NULL') + ',
							@cd_confirmacion = NULL,
							@ds_confirmadopor = NULL,
							@cd_paxidentificacion = NULL,
							@bl_politicaCancelacion = NULL,
							@dt_politicaCancelacion = NULL,
							@id_tipoHabitacion = NULL,
							@cd_Consecutivo_depende = ' + ISNULL('''' + @gen_cd_Consecutivo_depende + '''', 'NULL') + ',
							@id_TarjetaAsistencia = NULL,
							@id_Regiones = NULL,
							@Iden_GDS = NULL,
							@id_sys_entidades = NULL,
							@ds_TipoAuto = NULL,
							@ds_Origen = NULL,
							@ds_DirOrigen = NULL,
							@ds_DirDestino = NULL,
							@ds_TipoTarifa = NULL,
							@am_ValorUSD = NULL,
							@ds_NoVuelo = NULL,
							@ds_Vehiculo = NULL,
							@ds_Placa = NULL,
							@ds_CategoriaVehiculo = NULL,
							@ds_NombreConductor = NULL,
							@ds_telefono = NULL,
							@ds_IdiomaConductor = NULL,
							@id_MonedaSrv = @id_monedas_iata,
							@id_TipoServicio = ' + ISNULL(CAST(@gen_id_tiposservicio AS VARCHAR), 'NULL') + ',
							@id_Aerolinea = NULL,
							@am_PorFacParcial = 100,
							@ds_GDS = NULL,
							@am_basedescuento = ' + CAST(ISNULL(@gen_am_basedescuento, 0) AS VARCHAR) + ',
							@am_pordescuento = ' + CAST(ISNULL(@gen_am_pordescuento, 0) AS VARCHAR) + '; '
					END;

					SET @ItemIndex = @ItemIndex + 1;
					FETCH NEXT FROM curGenItems INTO 
						@gen_id_item, @gen_tipo_item, @gen_cd_tiquete, @gen_ds_descrip, @gen_in_nacionalidad, @gen_cd_cencosto, @gen_cd_auxiliar, @gen_cd_item, @gen_am_tarifa, @gen_am_iva, @gen_am_tua, @gen_am_comb, @gen_am_vat, @gen_am_Comision,
						@gen_ds_paxname, @gen_ds_paxape, @gen_ds_paxprefix, @gen_cd_tourcode, @gen_NumTktConj, @gen_cd_TipoTiquete, @gen_id_air, @gen_ds_itinerario, @gen_ds_itinerarioaerolinea, @gen_ds_clases, @gen_ds_Observaciones,
						@gen_am_highfare, @gen_am_lowfare, @gen_ds_solicita, @gen_ds_lapsoviaje, @gen_cd_tktrevisado, @gen_cd_PasaportePax, @gen_cd_pax_CC, @gen_am_PorFacParcial, @gen_in_cantpax, @gen_Id_Precompra,
						@gen_id_FormasPago, @gen_id_TarjetasCredito, @gen_id_sucursal, @gen_id_implante, @gen_bl_ahorro, @gen_cd_TipoTiqueteGDS, @gen_id_TiposDocumento, @gen_id_entdist, @gen_id_entvend,
						@gen_cd_destino, @gen_dt_fechaexped, @gen_id_tiqueteadores, @gen_id_gds, @gen_iden_gds, @gen_am_comisionPNR, @gen_ds_records, @gen_bl_NoCalcComision, @gen_bl_NoCalcIvaComision,
						@gen_am_basecomisionable, @gen_am_porcomision, @gen_id_tiposconceptfac, @gen_id_conceptofacturacion, @gen_id_tiposservicio, @gen_cd_proveedores, @gen_ds_servicio,
						@gen_am_valorprov, @gen_id_monedaprov, @gen_dt_llegada, @gen_dt_salida, @gen_am_pordescuento, @gen_Fecha_Salida, @gen_Fecha_Llegada, @gen_am_basedescuento, @gen_cd_Consecutivo_depende, @gen_cd_Consecutivo_variablesadicionales, @gen_id_referencia_origen;
				END;
				CLOSE curGenItems;
				DEALLOCATE curGenItems;

				-- Execute spza_Factura_Crear inside a TRY CATCH
				SET @FacturaRespuesta = NULL;
				SET @FacturaEstado = NULL;

				BEGIN TRY
					DECLARE @ReturnCode INT;
					DECLARE @FacturaExecSqlStmt NVARCHAR(MAX);

					SET @FacturaExecSqlStmt = N'
						EXEC @ReturnCode = dbo.spza_FacturaJOB_Crear' + CHAR(13) + CHAR(10) +
							'@id_usuario = 1,' + CHAR(13) + CHAR(10) +
							'@id_sucursal = ' + ISNULL(CAST(@id_sucursal AS VARCHAR), 'NULL') + ',' + CHAR(13) + CHAR(10) +
							'@id_implante = ' + ISNULL(CAST(@id_implante AS VARCHAR), 'NULL') + ',' + CHAR(13) + CHAR(10) +
							'@dt_fechacont = ' + ISNULL('''' + CONVERT(VARCHAR, @FechaCont, 120) + '''', 'NULL') + ',' + CHAR(13) + CHAR(10) +
							'@dt_vence = ' + ISNULL('''' + CONVERT(VARCHAR, @FechaCont, 120) + '''', 'NULL') + ',' + CHAR(13) + CHAR(10) +
							'@cd_tercero_codigo = ' + ISNULL('''' + REPLACE(@cd_cliente, '''', '''''') + '''', 'NULL') + ',' + CHAR(13) + CHAR(10) +
							'@ds_tercero_nombre = ' + ISNULL('''' + REPLACE(@ds_cliname, '''', '''''') + '''', 'NULL') + ',' + CHAR(13) + CHAR(10) +
							'@cd_cliente_codigo = ' + ISNULL('''' + REPLACE(@cd_cliente, '''', '''''') + '''', 'NULL') + ',' + CHAR(13) + CHAR(10) +
							'@ds_cliente_nombre = ' + ISNULL('''' + REPLACE(@ds_cliname, '''', '''''') + '''', 'NULL') + ',' + CHAR(13) + CHAR(10) +
							'@ds_cliente_dir = ' + ISNULL('''' + REPLACE(@ds_clidir, '''', '''''') + '''', 'NULL') + ',' + CHAR(13) + CHAR(10) +
							'@ds_cliente_ciudad = ' + ISNULL('''' + REPLACE(@ds_clicity, '''', '''''') + '''', 'NULL') + ',' + CHAR(13) + CHAR(10) +
							'@ds_cliente_tel = ' + ISNULL('''' + REPLACE(@ds_clitel, '''', '''''') + '''', 'NULL') + ',' + CHAR(13) + CHAR(10) +
							'@ds_cliente_dirdesp = ' + ISNULL('''' + REPLACE(@ds_clidir, '''', '''''') + '''', 'NULL') + ',' + CHAR(13) + CHAR(10) +
							'@ds_cliente_email = ' + ISNULL('''' + REPLACE(@ds_ClienteEmail, '''', '''''') + '''', 'NULL') + ',' + CHAR(13) + CHAR(10) +
							'@ds_cliente_contacto = ' + ISNULL('''' + REPLACE(@ds_cliname, '''', '''''') + '''', 'NULL') + ',' + CHAR(13) + CHAR(10) +
							'@ds_cliente_contacto_email = ' + ISNULL('''' + REPLACE(@ds_ClienteEmail, '''', '''''') + '''', 'NULL') + ',' + CHAR(13) + CHAR(10) +
							'@id_monedas_iata = ' + ISNULL(CAST(@id_monedas_iata AS VARCHAR), 'NULL') + ',' + CHAR(13) + CHAR(10) +
							'@cd_vendedor = ' + ISNULL('''' + REPLACE(@cd_vendedor, '''', '''''') + '''', 'NULL') + ',' + CHAR(13) + CHAR(10) +
							'@id_tiqueteador = ' + ISNULL(CAST(@id_tiqueteador AS VARCHAR), 'NULL') + ',' + CHAR(13) + CHAR(10) +
							'@bn_anexo = NULL,' + CHAR(13) + CHAR(10) +
							'@Tcambio = ' + ISNULL(CAST(@am_TasaCambio AS VARCHAR), 'NULL') + ',' + CHAR(13) + CHAR(10) +
							'@am_tcambiousd = ' + ISNULL(CAST(@am_tcambiousd AS VARCHAR), 'NULL') + ',' + CHAR(13) + CHAR(10) +
							'@id_tipoventa = ' + ISNULL(CAST(@id_tipoventa AS VARCHAR), 'NULL') + ',' + CHAR(13) + CHAR(10) +
							'@ds_num_resolucion = '''',' + CHAR(13) + CHAR(10) +
							'@in_num_inicial = 0,' + CHAR(13) + CHAR(10) +
							'@in_num_final = 0,' + CHAR(13) + CHAR(10) +
							'@ds_numeracion_autorizada = NULL,' + CHAR(13) + CHAR(10) +
							'@dt_fecha_resolucion = NULL,' + CHAR(13) + CHAR(10) +
							'@CodigoArchivoFisico = '''',' + CHAR(13) + CHAR(10) +
							'@ds_Observacion = ' + ISNULL('''' + REPLACE(@ds_Observaciones, '''', '''''') + '''', 'NULL') + ',' + CHAR(13) + CHAR(10) +
							'@ds_Campo_libre1 = NULL,' + CHAR(13) + CHAR(10) +
							'@ds_Campo_libre2 = NULL,' + CHAR(13) + CHAR(10) +
							'@cd_fuente_Reemplaza = NULL,' + CHAR(13) + CHAR(10) +
							'@cd_serie_Reemplaza = NULL,' + CHAR(13) + CHAR(10) +
							'@cd_consecutivo_Reemplaza = NULL,' + CHAR(13) + CHAR(10) +
							'@ds_Actividad_Economica = NULL,' + CHAR(13) + CHAR(10) +
							'@ds_Tarifa_ICA = NULL,' + CHAR(13) + CHAR(10) +
							'@SqlStmt = ' + ISNULL('''' + REPLACE(@SqlStmt, '''', '''''') + '''', 'NULL') + ',' + CHAR(13) + CHAR(10) +
							'@AnticiposSqlStmt = NULL,' + CHAR(13) + CHAR(10) +
							'@TotalFactura = ' + ISNULL(CAST(@ValorFactura AS VARCHAR), 'NULL') + ',' + CHAR(13) + CHAR(10) +
							'@TotalCupoCreditoCliente = 0,' + CHAR(13) + CHAR(10) +
							'@bl_BloqueoCupoCredito = 0,' + CHAR(13) + CHAR(10) +
							'@bl_generadaauto = 1,' + CHAR(13) + CHAR(10) +
							'@ds_CotizacionesId = NULL,' + CHAR(13) + CHAR(10) +
							'@Id_Cierre = NULL,' + CHAR(13) + CHAR(10) +
							'@cd_TipoFact = NULL,' + CHAR(13) + CHAR(10) +
							'@id_fac_remisionRelacionada = NULL,' + CHAR(13) + CHAR(10) +
							'@id_fac_facturaRelacionada = NULL,' + CHAR(13) + CHAR(10) +
							'@ds_DescripcionFac = ' + ISNULL('''' + REPLACE(@ds_descripcion, '''', '''''') + '''', 'NULL') + ',' + CHAR(13) + CHAR(10) +
							'@bl_nocont = 0,' + CHAR(13) + CHAR(10) +
							'@ProductosSqlStmt = NULL,' + CHAR(13) + CHAR(10) +
							'@cd_CF_TipoComprobante = NULL,' + CHAR(13) + CHAR(10) +
							'@id_Licitacion = ' + ISNULL(CAST(@cd_licitacion AS VARCHAR), 'NULL') + ',' + CHAR(13) + CHAR(10) +
							'@ValorFactura = ' + ISNULL(CAST(@ValorFactura AS VARCHAR), 'NULL') + ',' + CHAR(13) + CHAR(10) +
							'@id_Especialista = NULL,' + CHAR(13) + CHAR(10) +
							'@id_tiqueteador_Facturador = NULL,' + CHAR(13) + CHAR(10) +
							'@id_TipoFormaPagoProveedor = NULL,' + CHAR(13) + CHAR(10) +
							'@id_MedioReservacion = NULL,' + CHAR(13) + CHAR(10) +
							'@bl_refacturacion = 0,' + CHAR(13) + CHAR(10) +
							'@bl_comisiona = 0,' + CHAR(13) + CHAR(10) +
							'@cd_fuente_factura = NULL,' + CHAR(13) + CHAR(10) +
							'@cd_serie_factura = NULL,' + CHAR(13) + CHAR(10) +
							'@cd_consecutivo_factura = NULL,' + CHAR(13) + CHAR(10) +
							'@id_NotasAerolinea = NULL,' + CHAR(13) + CHAR(10) +
							'@bl_interface = 0,' + CHAR(13) + CHAR(10) +
							'@id_evento = NULL,' + CHAR(13) + CHAR(10) +
							'@bl_NoEnviarFacElectronica = 0,' + CHAR(13) + CHAR(10) +
							'@bl_DescontarComisionCxP = 0,' + CHAR(13) + CHAR(10) +
							'@ds_num_resolucion_Adicional = '''',' + CHAR(13) + CHAR(10) +
							'@id_fac_facturaRefacturacion = NULL,' + CHAR(13) + CHAR(10) +
							'@bl_refacturacion_contabilizar_saldos = 0,' + CHAR(13) + CHAR(10) +
							'@ZML_VariablesXML = NULL,' + CHAR(13) + CHAR(10) +
							'@bl_FormatoResumidoFactElectro = 0,' + CHAR(13) + CHAR(10) +
							'@bl_ExigeAdjuntoFactElectro = 0,' + CHAR(13) + CHAR(10) +
							'@bl_omitir_Validar_IVA_facturacion = 0,' + CHAR(13) + CHAR(10) +
							'@ZML_AjusteIvaXML = NULL,' + CHAR(13) + CHAR(10) +
							'@ds_RespuestaJOB = @FacturaRespuesta OUTPUT;';

					EXEC sp_executesql @FacturaExecSqlStmt, 
						N'@FacturaRespuesta VARCHAR(MAX) OUTPUT, @ReturnCode INT OUTPUT', 
						@FacturaRespuesta = @FacturaRespuesta OUTPUT, 
						@ReturnCode = @ReturnCode OUTPUT;

					IF @ReturnCode = 0
					BEGIN
						SET @FacturaEstado = 0;
					END
					ELSE
					BEGIN
						SET @FacturaEstado = 1;
						SET @FacturaRespuesta = ISNULL(@FacturaRespuesta, '') + CHAR(13) + CHAR(10) + '--- DYNAMIC EXECUTION TRACE ---' + CHAR(13) + CHAR(10) + ISNULL(@FacturaExecSqlStmt, '');
					END
				END TRY
				BEGIN CATCH
					SET @FacturaEstado = 1;
					SET @FacturaRespuesta = ERROR_MESSAGE() + CHAR(13) + CHAR(10) + '--- DYNAMIC EXECUTION TRACE ---' + CHAR(13) + CHAR(10) + ISNULL(@FacturaExecSqlStmt, '');
				END CATCH
				--SET @FacturaRespuesta = @FacturaRespuesta + ' ' + @SqlStmt;
				-- Log result and clean queue using spza_GDSFacturacionAuto_InsertarLog
				IF @FacturaEstado = 0
				BEGIN
					-- Success log
					EXEC dbo.spza_GDSFacturacionAuto_InsertarLog
						@id_usuario = 1,
						@cd_sucursal = @cd_sucursal,
						@dt_fecha = @Fecha,
						@ds_Mensaje = @FacturaRespuesta,
						@Id_reserva = @id_reserva,
						@cd_reserva = @cd_reserva,
						@ds_archivo = @ds_archivo,
						@bl_error = 0,
						@cd_tiqueteador = @cd_tiqueteador;
				END
				ELSE
				BEGIN
					-- Error log
					EXEC dbo.spza_GDSFacturacionAuto_InsertarLog
						@id_usuario = 1,
						@cd_sucursal = @cd_sucursal,
						@dt_fecha = @Fecha,
						@ds_Mensaje = @FacturaRespuesta,
						@Id_reserva = @id_reserva,
						@cd_reserva = @cd_reserva,
						@ds_archivo = @ds_archivo,
						@bl_error = 1,
						@cd_tiqueteador = @cd_tiqueteador;
				END

				FETCH NEXT FROM curInvoices INTO @ReservaFactura;
			END;

			CLOSE curInvoices;
			DEALLOCATE curInvoices;

		WaitFor Delay @Tiempo
	End

	Return
End
GO
