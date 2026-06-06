IF OBJECT_ID('dbo.spJOBFacturacionAuto', 'P') IS NOT NULL
    DROP PROCEDURE dbo.spJOBFacturacionAuto;
GO

-- Select * From Parametros Where Id = 88
/*
select * from FacturaElectronica_Transaccion whith(nolock)
select * from FacturaElectronica_Transaccion_LogRespuestas whith(nolock) Order By Iden desc

Delete FacturaElectronica_Transaccion
Delete from FacturaElectronica_Transaccion_LogRespuestas

Update	FacturaElectronica_Transaccion
Set	Estado = 'Por Enviar',
	Intentos = 0
Where	IsNull(Estado, 'Error') = 'Error'


*/
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
	Declare @FacturaRespuesta VARCHAR(1000)
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


	DECLARE @NumDecimales INT

	-- Habilitar envío de facturación automatica
	If Not Exists(Select * From Parametros Where Id=900 And Valor= 'S')
	Begin
		WaitFor Delay '23:59:00'
		Return
	End

	-- Fetch tax details for standard IVA (id=1)
	SELECT TOP 1 
		@ds_impas_iva = ds_nombre, 
		@cd_impcta_iva = cd_cuenta, 
		@am_porcentaje_iva = am_porcentaje 
	FROM dbo.ImpRet 
	WHERE id = 1;

	SELECT @NumDecimales = CONVERT(INT,LTRIM(RTRIM(valor))) from dbo.parametros where id = 33;
	IF @NumDecimales IS NULL SET @NumDecimales = 2;

	
	
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
		ds_tipoproveedor VARCHAR(100) COLLATE DATABASE_DEFAULT
	);

	CREATE TABLE #CargosImpuestosJob (
		id INT, id_reserva INT, id_reservaGDS_detalles INT, id_reservaGDS_servicios INT,
		in_orden INT, cd_codigo INT, ds_nombre VARCHAR(100) COLLATE DATABASE_DEFAULT, cd_tipo CHAR(1) COLLATE DATABASE_DEFAULT, 
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
		ds_numerotarjetaAirPlus VARCHAR(25) COLLATE DATABASE_DEFAULT
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
					id_air,
					(SELECT TOP 1 id FROM dbo.Monedas_IATA WHERE cd_codigo = ds_moneda),
					ds_pax_firstnm,
					ds_pax_lastnm,
					ds_pax_prefix,
					NULL,
					ds_tkt_number,
					cd_proveedores,
					dt_checkin,
					dt_checkout,
					cd_centrocosto,
					cd_auxiliar,
					cd_fp_OtrosItems,
					PNR,
					am_tarifa,
					CASE WHEN Tipo = ''Aire'' THEN (am_tarifa + am_iva + am_tua + am_comb + am_vat) ELSE (am_tarifa + am_iva + am_vat) END,
					NULL,
					NULL,
					am_Comision,
					0,
					CASE WHEN Tipo = ''Aire'' THEN (am_tarifa + am_iva + am_tua + am_comb + am_vat) ELSE (am_tarifa + am_iva + am_vat) END,
					cd_tourcode,
					am_TarifaContado + am_IvaContado + am_OtrosContado,
					am_TarifaCredito + am_IvaCredito + am_OtrosCredito,
					cd_tktrevisado,
					(SELECT TOP 1 id FROM dbo.TiposDocumento WHERE cd_codigo = cd_TipoTiquete),
					cd_Penalidad,
					cd_TipoTiquete,
					am_TasaCambio,
					ds_itinerario,
					id_sucursal,
					' + ISNULL(CAST(@cur_id_implante AS VARCHAR), 'NULL') + ',
					id_FormasPago,
					cd_TarjetaCreditoTAO,
					iden_gds
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
					@item_am_fp2, @item_ds_cc_code2, @item_ds_cc_number2, @item_ds_cc_vence2, @item_ds_cc_autorizacion2, @item_ds_cc_voucher2, @item_in_cc_cuotas2;

				WHILE @@FETCH_STATUS = 0
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

					IF @item_Tipo = 'Aire'
					BEGIN
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

						-- Build cargos/impuestos nested dynamic SQL
						SET @TarifaSqlStmt = '';
						IF @item_am_iva > 0
						BEGIN
							SET @TarifaSqlStmt = 'EXECUTE dbo.spza_TiqueteImpuestos_Insertar 
								@id_tiquetecargos = @NewCargId, 
								@id_impret = 1, 
								@ds_impas = ''' + @ds_impas_iva + ''', 
								@cd_impcta = ''' + @cd_impcta_iva + ''', 
								@am_valor = ' + CAST(@item_am_iva AS VARCHAR) + ', 
								@am_contado = ' + CAST(@item_am_IvaContado AS VARCHAR) + ', 
								@am_credito = ' + CAST(@item_am_IvaCredito AS VARCHAR) + ', 
								@am_porcentaje = ' + CAST(@am_porcentaje_iva AS VARCHAR) + ', 
								@id_monedas_iata = @id_monedas_iata, 
								@Tcambio = @Tcambio, 
								@bl_contabilizar = 1;'
						END

						SET @TktSqlStmt = 'EXECUTE dbo.spza_TiqueteCargos_Insertar 
							@id_fac_remision = @NewRmId, 
							@id_fac_factura = @NewFacId, 
							@id_tiquetes = @NewTktId, 
							@id_cargosdesc = 1, 
							@ds_cargonm = ''Tarifa'', 
							@am_valor = ' + CAST(@item_am_tarifa AS VARCHAR) + ', 
							@am_contado = ' + CAST(@item_am_TarifaContado AS VARCHAR) + ', 
							@am_credito = ' + CAST(@item_am_TarifaCredito AS VARCHAR) + ', 
							@bl_noshow = 0, 
							@id_monedas_iata = @id_monedas_iata, 
							@Tcambio = @Tcambio, 
							@SqlStmt = ' + ISNULL('''' + REPLACE(@TarifaSqlStmt, '''', '''''') + '''', 'N''''') + ';'

						IF @item_am_tua > 0
						BEGIN
							DECLARE @am_tua_contado MONEY = ROUND(@item_am_tua * @ContadoRatio, 2);
							DECLARE @am_tua_credito MONEY = @item_am_tua - @am_tua_contado;
							SET @TktSqlStmt = @TktSqlStmt + ' EXECUTE dbo.spza_TiqueteCargos_Insertar 
								@id_fac_remision = @NewRmId, 
								@id_fac_factura = @NewFacId, 
								@id_tiquetes = @NewTktId, 
								@id_cargosdesc = 2, 
								@ds_cargonm = ''Tasa Aeroportuaria'', 
								@am_valor = ' + CAST(@item_am_tua AS VARCHAR) + ', 
								@am_contado = ' + CAST(@am_tua_contado AS VARCHAR) + ', 
								@am_credito = ' + CAST(@am_tua_credito AS VARCHAR) + ', 
								@bl_noshow = 0, 
								@id_monedas_iata = @id_monedas_iata, 
								@Tcambio = @Tcambio, 
								@SqlStmt = N'''';'
						END

						IF @item_am_comb > 0
						BEGIN
							DECLARE @am_comb_contado MONEY = ROUND(@item_am_comb * @ContadoRatio, 2);
							DECLARE @am_comb_credito MONEY = @item_am_comb - @am_comb_contado;
							SET @TktSqlStmt = @TktSqlStmt + ' EXECUTE dbo.spza_TiqueteCargos_Insertar 
								@id_fac_remision = @NewRmId, 
								@id_fac_factura = @NewFacId, 
								@id_tiquetes = @NewTktId, 
								@id_cargosdesc = 3, 
								@ds_cargonm = ''Cargo por combustible'', 
								@am_valor = ' + CAST(@item_am_comb AS VARCHAR) + ', 
								@am_contado = ' + CAST(@am_comb_contado AS VARCHAR) + ', 
								@am_credito = ' + CAST(@am_comb_credito AS VARCHAR) + ', 
								@bl_noshow = 0, 
								@id_monedas_iata = @id_monedas_iata, 
								@Tcambio = @Tcambio, 
								@SqlStmt = N'''';'
						END

						IF @item_am_vat > 0
						BEGIN
							DECLARE @am_vat_contado MONEY = ROUND(@item_am_vat * @ContadoRatio, 2);
							DECLARE @am_vat_credito MONEY = @item_am_vat - @am_vat_contado;
							SET @TktSqlStmt = @TktSqlStmt + ' EXECUTE dbo.spza_TiqueteCargos_Insertar 
								@id_fac_remision = @NewRmId, 
								@id_fac_factura = @NewFacId, 
								@id_tiquetes = @NewTktId, 
								@id_cargosdesc = 4, 
								@ds_cargonm = ''Otros cargos'', 
								@am_valor = ' + CAST(@item_am_vat AS VARCHAR) + ', 
								@am_contado = ' + CAST(@am_vat_contado AS VARCHAR) + ', 
								@am_credito = ' + CAST(@am_vat_credito AS VARCHAR) + ', 
								@bl_noshow = 0, 
								@id_monedas_iata = @id_monedas_iata, 
								@Tcambio = @Tcambio, 
								@SqlStmt = N'''';'
						END

						-- Cargos e Impuestos Tiquetes desde Tabla Bulk
						DECLARE curCI CURSOR LOCAL FOR 
						SELECT cd_codigo, ds_nombre, cd_tipo, am_valor, am_contado, am_credito, am_porcentaje 
						FROM #CargosImpuestosJob 
						WHERE id_reserva = @item_id_reserva AND id_reservaGDS_detalles = @item_id_air;

						DECLARE @ci_cd_codigo INT, @ci_ds_nombre VARCHAR(100), @ci_cd_tipo CHAR(1), @ci_am_valor MONEY, @ci_am_contado MONEY, @ci_am_credito MONEY, @ci_am_porcentaje NUMERIC(8,4);
						OPEN curCI; 
						FETCH NEXT FROM curCI INTO @ci_cd_codigo, @ci_ds_nombre, @ci_cd_tipo, @ci_am_valor, @ci_am_contado, @ci_am_credito, @ci_am_porcentaje;
						WHILE @@FETCH_STATUS = 0
						BEGIN
							IF @ci_cd_tipo IN ('1','2')
							BEGIN
								SET @TktSqlStmt = @TktSqlStmt + ' EXECUTE dbo.spza_TiqueteCargos_Insertar @id_fac_remision = @NewRmId, @id_fac_factura = @NewFacId, @id_tiquetes = @NewTktId, @id_cargosdesc = ' + CAST(@ci_cd_codigo AS VARCHAR) + ', @ds_cargonm = ' + ISNULL('''' + @ci_ds_nombre + '''', 'NULL') + ', @am_valor = ' + CAST(@ci_am_valor AS VARCHAR) + ', @am_contado = ' + CAST(@ci_am_contado AS VARCHAR) + ', @am_credito = ' + CAST(@ci_am_credito AS VARCHAR) + ', @bl_noshow = 0, @id_monedas_iata = @id_monedas_iata, @Tcambio = @Tcambio, @SqlStmt = N'''';'
							END
							ELSE IF @ci_cd_tipo IN ('3','4')
							BEGIN
								SET @TktSqlStmt = @TktSqlStmt + ' EXECUTE dbo.spza_TiqueteImpuestos_Insertar @id_fac_remision = @NewRmId, @id_fac_factura = @NewFacId, @id_tiquetes = @NewTktId, @id_impuestosdesc = ' + CAST(@ci_cd_codigo AS VARCHAR) + ', @ds_impuestonm = ' + ISNULL('''' + @ci_ds_nombre + '''', 'NULL') + ', @am_valor = ' + CAST(@ci_am_valor AS VARCHAR) + ', @am_contado = ' + CAST(@ci_am_contado AS VARCHAR) + ', @am_credito = ' + CAST(@ci_am_credito AS VARCHAR) + ', @am_porcentaje = ' + CAST(@ci_am_porcentaje AS VARCHAR) + ', @id_monedas_iata = @id_monedas_iata, @Tcambio = @Tcambio, @SqlStmt = N'''';'
							END
							FETCH NEXT FROM curCI INTO @ci_cd_codigo, @ci_ds_nombre, @ci_cd_tipo, @ci_am_valor, @ci_am_contado, @ci_am_credito, @ci_am_porcentaje;
						END
						CLOSE curCI; 
						DEALLOCATE curCI;

						-- Formas de Pago Tiquetes desde Tabla Bulk o Fallback
						DECLARE @fp_id_fp INT, @fp_id_tc INT, @fp_numero VARCHAR(50), @fp_valor MONEY, @fp_auth VARCHAR(50);
						
						IF NOT EXISTS (SELECT 1 FROM #FormasPagosJob WHERE id_reserva = @item_id_reserva AND id_reservaGDS_detalles = @item_id_air)
						BEGIN
							-- Fallback Forma de Pago 1
							IF ISNULL(@item_am_fp1, 0) > 0
							BEGIN
								IF @item_ds_cc_code IS NOT NULL AND RTRIM(LTRIM(@item_ds_cc_code)) <> ''
								BEGIN
									SELECT @fp_id_fp = id FROM dbo.FormasPago WHERE cd_codigo = 'TC';
									SELECT @fp_id_tc = id FROM dbo.tarjetascredito WHERE cd_codigo = @item_ds_cc_code;
									SET @fp_numero = @item_ds_cc_number;
									SET @fp_valor = @item_am_fp1;
									SET @fp_auth = @item_ds_cc_autorizacion;
									
									SET @TktSqlStmt = @TktSqlStmt + ' EXECUTE dbo.spza_TiqueteFormasPago_Insertar @id_tiquetes = @NewTktId, @id_fac_factura = @NewFacId, @id_fac_remision = @NewRmId, @id_FormasPago = ' + ISNULL(CAST(@fp_id_fp AS VARCHAR),'NULL') + ', @ds_fpnm = '''', @bl_fprepresenta = 0, @id_TarjetasCredito = ' + ISNULL(CAST(@fp_id_tc AS VARCHAR), 'NULL') + ', @cd_tccode = '''', @ds_tcnumber = ' + ISNULL('''' + @fp_numero + '''', 'NULL') + ', @ds_tcvoucher = ' + ISNULL('''' + @item_ds_cc_voucher + '''', 'NULL') + ', @ds_tcexp = ' + ISNULL('''' + @item_ds_cc_vence + '''', 'NULL') + ', @cd_idbanco = NULL, @ds_cheque = NULL, @ds_plaza = NULL, @ds_referencia = NULL, @ds_poliza = NULL, @ds_polanexo = NULL, @am_valor = ' + CAST(@fp_valor AS VARCHAR) + ', @ds_tcautorizacion = ' + ISNULL('''' + @fp_auth + '''', 'NULL') + ', @in_tccuotas = ' + CAST(ISNULL(@item_in_cc_cuotas,1) AS VARCHAR) + ', @id_monedas_iata = @id_monedas_iata, @Tcambio = @Tcambio;'
								END
								ELSE
								BEGIN
									SELECT @fp_id_fp = id FROM dbo.FormasPago WHERE cd_codigo = 'EFE';
									SET @fp_valor = @item_am_fp1;
									
									SET @TktSqlStmt = @TktSqlStmt + ' EXECUTE dbo.spza_TiqueteFormasPago_Insertar @id_tiquetes = @NewTktId, @id_fac_factura = @NewFacId, @id_fac_remision = @NewRmId, @id_FormasPago = ' + ISNULL(CAST(@fp_id_fp AS VARCHAR),'NULL') + ', @ds_fpnm = '''', @bl_fprepresenta = 0, @id_TarjetasCredito = NULL, @cd_tccode = '''', @ds_tcnumber = NULL, @ds_tcvoucher = NULL, @ds_tcexp = NULL, @cd_idbanco = NULL, @ds_cheque = NULL, @ds_plaza = NULL, @ds_referencia = NULL, @ds_poliza = NULL, @ds_polanexo = NULL, @am_valor = ' + CAST(@fp_valor AS VARCHAR) + ', @ds_tcautorizacion = NULL, @in_tccuotas = 1, @id_monedas_iata = @id_monedas_iata, @Tcambio = @Tcambio;'
								END
							END

							-- Fallback Forma de Pago 2
							IF ISNULL(@item_am_fp2, 0) > 0
							BEGIN
								IF @item_ds_cc_code2 IS NOT NULL AND RTRIM(LTRIM(@item_ds_cc_code2)) <> ''
								BEGIN
									SELECT @fp_id_fp = id FROM dbo.FormasPago WHERE cd_codigo = 'TC';
									SELECT @fp_id_tc = id FROM dbo.tarjetascredito WHERE cd_codigo = @item_ds_cc_code2;
									SET @fp_numero = @item_ds_cc_number2;
									SET @fp_valor = @item_am_fp2;
									SET @fp_auth = @item_ds_cc_autorizacion2;
									
									SET @TktSqlStmt = @TktSqlStmt + ' EXECUTE dbo.spza_TiqueteFormasPago_Insertar @id_tiquetes = @NewTktId, @id_fac_factura = @NewFacId, @id_fac_remision = @NewRmId, @id_FormasPago = ' + ISNULL(CAST(@fp_id_fp AS VARCHAR),'NULL') + ', @ds_fpnm = '''', @bl_fprepresenta = 0, @id_TarjetasCredito = ' + ISNULL(CAST(@fp_id_tc AS VARCHAR), 'NULL') + ', @cd_tccode = '''', @ds_tcnumber = ' + ISNULL('''' + @fp_numero + '''', 'NULL') + ', @ds_tcvoucher = ' + ISNULL('''' + @item_ds_cc_voucher2 + '''', 'NULL') + ', @ds_tcexp = ' + ISNULL('''' + @item_ds_cc_vence2 + '''', 'NULL') + ', @cd_idbanco = NULL, @ds_cheque = NULL, @ds_plaza = NULL, @ds_referencia = NULL, @ds_poliza = NULL, @ds_polanexo = NULL, @am_valor = ' + CAST(@fp_valor AS VARCHAR) + ', @ds_tcautorizacion = ' + ISNULL('''' + @fp_auth + '''', 'NULL') + ', @in_tccuotas = ' + CAST(ISNULL(@item_in_cc_cuotas2,1) AS VARCHAR) + ', @id_monedas_iata = @id_monedas_iata, @Tcambio = @Tcambio;'
								END
								ELSE
								BEGIN
									SELECT @fp_id_fp = id FROM dbo.FormasPago WHERE cd_codigo = 'EFE';
									SET @fp_valor = @item_am_fp2;
									
									SET @TktSqlStmt = @TktSqlStmt + ' EXECUTE dbo.spza_TiqueteFormasPago_Insertar @id_tiquetes = @NewTktId, @id_fac_factura = @NewFacId, @id_fac_remision = @NewRmId, @id_FormasPago = ' + ISNULL(CAST(@fp_id_fp AS VARCHAR),'NULL') + ', @ds_fpnm = '''', @bl_fprepresenta = 0, @id_TarjetasCredito = NULL, @cd_tccode = '''', @ds_tcnumber = NULL, @ds_tcvoucher = NULL, @ds_tcexp = NULL, @cd_idbanco = NULL, @ds_cheque = NULL, @ds_plaza = NULL, @ds_referencia = NULL, @ds_poliza = NULL, @ds_polanexo = NULL, @am_valor = ' + CAST(@fp_valor AS VARCHAR) + ', @ds_tcautorizacion = NULL, @in_tccuotas = 1, @id_monedas_iata = @id_monedas_iata, @Tcambio = @Tcambio;'
								END
							END

							-- Si ambas am_fp1 y am_fp2 son nulas o 0, pero hay tarifa:
							IF ISNULL(@item_am_fp1, 0) = 0 AND ISNULL(@item_am_fp2, 0) = 0 AND ISNULL(@item_am_tarifa, 0) > 0
							BEGIN
								SELECT @fp_id_fp = id FROM dbo.FormasPago WHERE cd_codigo = 'EFE';
								SET @fp_valor = ISNULL(@item_am_tarifa, 0);
								SET @TktSqlStmt = @TktSqlStmt + ' EXECUTE dbo.spza_TiqueteFormasPago_Insertar @id_tiquetes = @NewTktId, @id_fac_factura = @NewFacId, @id_fac_remision = @NewRmId, @id_FormasPago = ' + ISNULL(CAST(@fp_id_fp AS VARCHAR),'NULL') + ', @ds_fpnm = '''', @bl_fprepresenta = 0, @id_TarjetasCredito = NULL, @cd_tccode = '''', @ds_tcnumber = NULL, @ds_tcvoucher = NULL, @ds_tcexp = NULL, @cd_idbanco = NULL, @ds_cheque = NULL, @ds_plaza = NULL, @ds_referencia = NULL, @ds_poliza = NULL, @ds_polanexo = NULL, @am_valor = ' + CAST(@fp_valor AS VARCHAR) + ', @id_monedas_iata = @id_monedas_iata, @Tcambio = @Tcambio, @ds_tcautorizacion = NULL, @in_tccuotas = 1;'
							END
						END
						ELSE
						BEGIN
							-- Lógica Bulk original
							DECLARE curFP CURSOR LOCAL FOR 
							SELECT id_formaspago, id_tarjetascredito, ds_numerotarjeta, am_valor, ds_autorizaciontarjeta 
							FROM #FormasPagosJob 
							WHERE id_reserva = @item_id_reserva AND id_reservaGDS_detalles = @item_id_air;

							OPEN curFP; 
							FETCH NEXT FROM curFP INTO @fp_id_fp, @fp_id_tc, @fp_numero, @fp_valor, @fp_auth;
							WHILE @@FETCH_STATUS = 0
							BEGIN
								SET @TktSqlStmt = @TktSqlStmt + ' EXECUTE dbo.spza_TiqueteFormasPago_Insertar @id_tiquetes = @NewTktId, @id_fac_factura = @NewFacId, @id_fac_remision = @NewRmId, @id_FormasPago = ' + CAST(@fp_id_fp AS VARCHAR) + ', @ds_fpnm = '''', @bl_fprepresenta = 0, @id_TarjetasCredito = ' + ISNULL(CAST(@fp_id_tc AS VARCHAR), 'NULL') + ', @cd_tccode = '''', @ds_tcnumber = ' + ISNULL('''' + @fp_numero + '''', 'NULL') + ', @ds_tcvoucher = NULL, @ds_tcexp = NULL, @cd_idbanco = NULL, @ds_cheque = NULL, @ds_plaza = NULL, @ds_referencia = NULL, @ds_poliza = NULL, @ds_polanexo = NULL, @am_valor = ' + CAST(@fp_valor AS VARCHAR) + ', @id_monedas_iata = @id_monedas_iata, @Tcambio = @Tcambio, @ds_tcautorizacion = ' + ISNULL('''' + @fp_auth + '''', 'NULL') + ', @in_tccuotas = 1;'
								FETCH NEXT FROM curFP INTO @fp_id_fp, @fp_id_tc, @fp_numero, @fp_valor, @fp_auth;
							END
							CLOSE curFP; 
							DEALLOCATE curFP;
						END

						-- Build Tkt Itineraries nested dynamic SQL
						SET @TktItinSqlStmt = '';
						SELECT 
							@TktItinSqlStmt = @TktItinSqlStmt + 
							'EXECUTE dbo.spza_TiqueteItinerarios_Insertar 
								@id_fac_factura = @NewFacId, 
								@id_fac_remision = @NewRmId, 
								@id_Tiquetes = @NewTktId, 
								@orden = ' + CAST(orden AS VARCHAR) + ', 
								@cd_origen = ''' + cd_origen + ''', 
								@cd_destino = ''' + cd_destino + ''', 
								@cd_clase = ''' + ISNULL(cd_clase, '') + ''', 
								@fecha_salida = ' + ISNULL('''' + CONVERT(VARCHAR, fecha_salida, 120) + '''', 'NULL') + ', 
								@hora_salida = ''' + ISNULL(hora_salida, '') + ''', 
								@hora_llegada = ''' + ISNULL(hora_llegada, '') + ''', 
								@terminal = ''' + ISNULL(terminal, '') + ''', 
								@cd_aero_siglas = ''' + cd_aero_siglas + ''', 
								@cd_farebasis = ''' + ISNULL(cd_farebasis, '') + ''', 
								@ds_NumVuelo = ''' + ISNULL(ds_NumVuelo, '') + ''', 
								@ds_TipoVuelo = ''' + ISNULL(ds_TipoVuelo, '') + ''', 
								@am_valor = ' + CAST(ISNULL(am_valor, 0) AS VARCHAR) + ', 
								@bl_NoUtilizado = NULL, 
								@am_co2 = ' + CAST(ISNULL(am_co2, 0) AS VARCHAR) + '; '
						FROM dbo.ReservaGDS_Itinerarios
						WHERE id_reserva = @item_id_reserva;

						-- Call Tiquete Vender in SqlStmt
						SET @SqlStmt = @SqlStmt + '
						DECLARE @NewTktId_' + CAST(@ItemIndex AS VARCHAR) + ' INT;
						EXECUTE dbo.spza_Tiquete_Vender
							@cd_tiquete = ''' + @item_ds_tkt_number + ''',
							@id_TiposDocumento = ' + CAST(@id_TiposDocumento AS VARCHAR) + ',
							@id_entdist = ' + CAST(@id_entdist AS VARCHAR) + ',
							@in_estado = 1,
							@in_nacionalidad = ' + CAST(@item_in_nacionalidad AS VARCHAR) + ',
							@id_entvend = ' + CAST(@id_entvend AS VARCHAR) + ',
							@id_fac_factura = @NewFacId,
							@id_fac_remision = @NewRmId,
							@cd_tktrevisado = ' + ISNULL('''' + @item_cd_tktrevisado + '''', 'NULL') + ',
							@id_pax = NULL,
							@ds_paxname = ''' + @item_ds_pax_firstnm + ''',
							@ds_paxape = ''' + @item_ds_pax_lastnm + ''',
							@ds_paxprefix = ''' + ISNULL(@item_ds_pax_prefix, '') + ''',
							@cd_paxcedula = ''' + ISNULL(@item_cd_pax_CC, '') + ''',
							@ds_itinerario = ''' + LEFT(@item_ds_itinerario, 63) + ''',
							@ds_itinerarioaerolinea = ''' + LEFT(ISNULL(@item_ds_itinerarioaerolinea, ''), 63) + ''',
							@ds_clases = ''' + ISNULL(@item_ds_clases, '') + ''',
							@dt_fechasalida = ' + ISNULL('''' + CONVERT(VARCHAR, @item_Fecha_Salida, 120) + '''', 'NULL') + ',
							@dt_fechallegada = ' + ISNULL('''' + CONVERT(VARCHAR, @item_Fecha_Llegada, 120) + '''', 'NULL') + ',
							@cd_destino = ''' + ISNULL(@item_cd_destino, '') + ''',
							@dt_fechaexped = ''' + CONVERT(VARCHAR, @item_ds_fecha, 120) + ''',
							@id_usuario = 1,
							@id_tiqueteadores = ' + CAST(@id_tiqueteador AS VARCHAR) + ',
							@am_hf = ' + CAST(@item_am_highfare AS VARCHAR) + ',
							@am_lf = ' + CAST(@item_am_lowfare AS VARCHAR) + ',
							@am_tarifa = ' + CAST(@item_am_tarifa AS VARCHAR) + ',
							@cd_ah = ''' + ISNULL(@item_cd_Ahorro, '') + ''',
							@am_desah = 0,
							@id_gds = ' + CAST(@item_id_air AS VARCHAR) + ',
							@iden_gds = ' + CAST(@item_iden_gds AS VARCHAR) + ',
							@in_numtktconj = ' + CAST(@item_NumTktConj AS VARCHAR) + ',
							@bl_NoCalcComision = 0,
							@bl_NoCalcIvaComision = 0,
							@am_comisionPNR = ' + CAST(@item_am_Comision AS VARCHAR) + ',
							@am_basecomisionable = ' + CAST(@item_am_tarifa AS VARCHAR) + ',
							@am_porcomision = 0,
							@ds_records = ''' + @item_PNR + ''',
							@id_hotel = NULL,
							@id_precompra = ' + ISNULL(CAST(@item_Id_Precompra AS VARCHAR), 'NULL') + ',
							@id_TipoTiquete = ' + 'NULL' + ',
							@id_ReassonCode = NULL,
							@cencosto_interno = ''' + ISNULL(@item_cd_centrocosto, '') + ''',
							@ds_solicita = ''' + ISNULL(@item_ds_solicita, '') + ''',
							@ds_lapsoviaje = ''' + ISNULL(@item_ds_lapsoviaje, '') + ''',
							@id_monedas_iata = @id_monedas_iata,
							@Tcambio = @Tcambio,
							@cd_TiqueteGr = ' + 'NULL' + ',
							@SqlStmt = ''' + REPLACE(@TktSqlStmt, '''', '''''') + ''',
							@SqlStmtItinerarios = ''' + REPLACE(@TktItinSqlStmt, '''', '''''') + ''',
							@id_sucursal = @id_sucursal,
							@id_implante = @id_implante,
							@bl_ahorro = ' + CAST(@item_bl_ahorro AS VARCHAR) + ',
							@cd_TipoTiqueteGDS = ''' + ISNULL(@item_cd_TipoTiquete, '') + ''',
							@cd_tourcode = ''' + ISNULL(@item_cd_tourcode, '') + ''',
							@cd_PasaportePax = ''' + ISNULL(@item_cd_PasaportePax, '') + ''',
							@am_valor_aerolinea = ' + CAST(@item_am_tarifa AS VARCHAR) + ',
							@am_porcentaje_comision_BackEnd = 0,
							@am_valor_comision_BackEnd = 0,
							@am_PorFacParcial = ' + CAST(ISNULL(@item_am_PorFacParcial, 100) AS VARCHAR) + ',
							@in_cantpax = ' + CAST(ISNULL(@item_in_cantpax, 1) AS VARCHAR) + ',
							@OrdenGrabacion = ' + CAST(ISNULL(@ItemIndex, 1) AS VARCHAR) + ',
							@cd_Penalidad = NULL,
							@id_entdistIata = NULL,
							@id_entvendIata = NULL; ';
					END
					
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
					id_ConceptoFacturacion, cd_ConceptoFacturacion, ds_ConceptoFacturacion, id_TiposConceptFac, bl_contorlarCargImp, bl_CalculoAutoValoresFacturacion, id_TiposServicio, cd_TiposServicio, ds_TiposServicio, cd_proveedores, ds_proveedores, cd_tiquete, ds_servicio, ds_descrip, ds_paxname, ds_paxape, cd_paxtype, ds_paxClasificacion, in_nacionalidad, dt_llegada, dt_salida, cd_cencosto, cd_auxiliar, cd_item, Valor, am_Contado, am_Credito, ColId, cd_Consecutivo_depende, CodigoReserva, am_ImpuestoComision, Respuesta, bl_RutaExentaIva, id_FormasPago, id_TarjetasCredito, am_basedescuento, am_pordescuento, id_FormasPagoAirPlus, cd_FormasPagoAirPlus, ds_FormasPagoAirPlus, id_TarjetasCreditoAirPlus, cd_TarjetasCreditoAirPlus, ds_numerotarjetaAirPlus
				FROM #GenerarConceptosAuto;

				OPEN curConcepts;
				FETCH NEXT FROM curConcepts INTO 
					@c_id_ConceptoFacturacion, @c_cd_ConceptoFacturacion, @c_ds_ConceptoFacturacion, @c_id_TiposConceptFac, @c_bl_contorlarCargImp, @c_bl_CalculoAutoValoresFacturacion, @c_id_TiposServicio, @c_cd_TiposServicio, @c_ds_TiposServicio, @c_cd_proveedores, @c_ds_proveedores, @c_cd_tiquete, @c_ds_servicio, @c_ds_descrip, @c_ds_paxname, @c_ds_paxape, @c_cd_paxtype, @c_ds_paxClasificacion, @c_in_nacionalidad, @c_dt_llegada, @c_dt_salida, @c_cd_cencosto, @c_cd_auxiliar, @c_cd_item, @c_Valor, @c_am_Contado, @c_am_Credito, @c_ColId, @c_cd_Consecutivo_depende, @c_CodigoReserva, @c_am_ImpuestoComision, @c_Respuesta, @c_bl_RutaExentaIva, @c_id_FormasPago, @c_id_TarjetasCredito, @c_am_basedescuento, @c_am_pordescuento, @c_id_FormasPagoAirPlus, @c_cd_FormasPagoAirPlus, @c_ds_FormasPagoAirPlus, @c_id_TarjetasCreditoAirPlus, @c_cd_TarjetasCreditoAirPlus, @c_ds_numerotarjetaAirPlus;

				WHILE @@FETCH_STATUS = 0
				BEGIN
					IF @c_cd_ConceptoFacturacion IN ('CAN', 'CAI')
					BEGIN
						-- Generate spza_Tao_Vender trace
						SET @TaoCargSqlStmt = 'EXECUTE dbo.spza_TaoCargos_Insertar 
							@id_fac_remision = @NewRmId, 
							@id_fac_factura = @NewFacId, 
							@Id_Fac_Tao = @NewTaoId, 
							@id_cargosdesc = 1, 
							@ds_cargonm = ''Tarifa'', 
							@am_valor = ' + CAST(@c_Valor AS VARCHAR) + ', 
							@am_contado = ' + CAST(@c_am_Contado AS VARCHAR) + ', 
							@am_credito = ' + CAST(@c_am_Credito AS VARCHAR) + ', 
							@bl_noshow = 0, 
							@id_monedas_iata = @id_monedas_iata, 
							@Tcambio = @Tcambio, 
							@SqlStmt = N'''';'

						SET @TaoFpSqlStmt = '';
						IF @c_id_FormasPago IS NOT NULL
						BEGIN
							DECLARE @fp_nombre_tao VARCHAR(50);
							DECLARE @tc_codigo_tao VARCHAR(4);
							SELECT @fp_nombre_tao = ds_nombre FROM dbo.FormasPago WHERE id = @c_id_FormasPago;
							SELECT @tc_codigo_tao = cd_codigo FROM dbo.tarjetascredito WHERE id = @c_id_TarjetasCredito;

							SET @TaoFpSqlStmt = ' EXECUTE dbo.spza_TaoFormasPago_Insertar 
								@id_Fac_Tao = @NewTaoId, 
								@id_fac_factura = @NewFacId, 
								@id_fac_remision = @NewRmId, 
								@id_formaspago = ' + CAST(@c_id_FormasPago AS VARCHAR) + ', 
								@ds_fpnm = ' + ISNULL('''' + @fp_nombre_tao + '''', 'NULL') + ', 
								@bl_fprepresenta = 0, 
								@id_tarjetascredito = ' + ISNULL(CAST(@c_id_TarjetasCredito AS VARCHAR), 'NULL') + ', 
								@cd_tccode = ' + ISNULL('''' + @tc_codigo_tao + '''', 'NULL') + ', 
								@ds_tcnumber = ' + ISNULL('''' + @c_ds_numerotarjetaAirPlus + '''', 'NULL') + ', 
								@ds_tcvoucher = NULL, 
								@ds_tcexp = NULL, 
								@cd_idbanco = NULL, 
								@ds_cheque = NULL, 
								@ds_plaza = NULL, 
								@ds_referencia = NULL, 
								@ds_poliza = NULL, 
								@ds_polanexo = NULL, 
								@am_valor = ' + CAST(@c_Valor AS VARCHAR) + ', 
								@id_monedas_iata = @id_monedas_iata, 
								@Tcambio = @Tcambio, 
								@ds_tcautorizacion = NULL, 
								@in_tccuotas = 0;'
						END

						SET @SqlStmt = @SqlStmt + '
						DECLARE @NewTaoId_' + CAST(@ItemIndex AS VARCHAR) + ' INT;
						EXECUTE dbo.spza_Tao_Vender
							@cd_tiquete = ''' + @c_cd_tiquete + ''',
							@ds_descrip = ''' + ISNULL(@c_ds_descrip, '') + ''',
							@id_fac_factura = @NewFacId,
							@id_fac_remision = @NewRmId,
							@in_nacionalidad = ' + CAST(@c_in_nacionalidad AS VARCHAR) + ',
							@cd_cencosto = ''' + ISNULL(@c_cd_cencosto, '') + ''',
							@cd_aux = ''' + ISNULL(@c_cd_auxiliar, '') + ''',
							@cd_coditem = ''' + ISNULL(@c_cd_item, 'TAO') + ''',
							@am_basecomisionable = ' + CAST(@c_Valor AS VARCHAR) + ',
							@am_porcomision = 0,
							@id_monedas_iata = @id_monedas_iata,
							@Tcambio = @Tcambio,
							@OrdenGrabacion = 1,
							@SqlStmt = ''' + REPLACE(@TaoCargSqlStmt + @TaoFpSqlStmt, '''', '''''') + '''; '
					END
					ELSE
					BEGIN
						-- Generate spza_Servicio_Vender trace
						DECLARE @c_id_tipoproveedor INT = NULL;
						DECLARE @c_cd_tipoproveedor VARCHAR(10) = NULL;
						DECLARE @c_ds_tipoproveedor VARCHAR(100) = NULL;
						IF ISNULL(@c_cd_proveedores, '') <> ''
						BEGIN
							SELECT TOP 1 
								@c_id_tipoproveedor = tp.id, 
								@c_cd_tipoproveedor = tp.cd_codigo, 
								@c_ds_tipoproveedor = tp.ds_nombre 
							FROM dbo.TipoProveedores tp WITH(NOLOCK) 
							WHERE tp.cd_codigo = 'HTL' AND ISNULL(@c_cd_proveedores,'')<>'';
						END

						SET @SrvCargSqlStmt = 'EXECUTE dbo.spza_ServicioCargos_Insertar 
							@id_Fac_Servicios = @NewSrvId, 
							@id_cargosdesc = 1, 
							@ds_cargonm = ''Tarifa'', 
							@am_valor = ' + CAST(@c_Valor AS VARCHAR) + ', 
							@am_contado = ' + CAST(@c_am_Contado AS VARCHAR) + ', 
							@am_credito = ' + CAST(@c_am_Credito AS VARCHAR) + ', 
							@bl_noshow = 0, 
							@id_monedas_iata = @id_monedas_iata, 
							@Tcambio = @Tcambio, 
							@SqlStmt = N'''';'

						SET @SrvProvSqlStmt = '';
						IF @c_id_tipoproveedor IS NOT NULL
						BEGIN
							SET @SrvProvSqlStmt = ' EXECUTE dbo.spza_ServicioTipoProv_Insertar 
								@id_Fac_Servicios = @NewSrvId, 
								@Id_TipoProveedores = ' + CAST(@c_id_tipoproveedor AS VARCHAR) + ', 
								@cd_TipoProveedores = ''' + @c_cd_tipoproveedor + ''', 
								@ds_TipoProveedores = ''' + @c_ds_tipoproveedor + ''', 
								@cd_proveedores = ''' + @c_cd_proveedores + ''', 
								@ds_proveedores = ''' + @c_ds_proveedores + ''';'
						END

						SET @SrvPaxSqlStmt = '';
						IF ISNULL(@c_ds_paxname, '') <> ''
						BEGIN
							SET @SrvPaxSqlStmt = ' EXECUTE dbo.spza_ServicioPaxAdicional_insertar 
								@FacId = @NewFacId, 
								@RemId = @NewRmId, 
								@id_Fac_Servicios = @NewSrvId, 
								@ds_paxname = ''' + @c_ds_paxname + ''', 
								@ds_paxprefix = ''' + ISNULL(@c_cd_paxtype, '') + ''', 
								@ds_paxape = ''' + @c_ds_paxape + ''', 
								@ds_paxClasificacion = NULL, 
								@cd_voucherpax = NULL, 
								@cd_paxidentificacion = NULL, 
								@in_edad = NULL, 
								@cd_tiquete = NULL;'
						END

						SET @SrvSqlStmt = @SrvCargSqlStmt + @SrvProvSqlStmt + @SrvPaxSqlStmt;

						SET @SqlStmt = @SqlStmt + '
						DECLARE @NewSrvId_' + CAST(@ItemIndex AS VARCHAR) + ' INT;
						EXECUTE dbo.spza_Servicio_Vender
							@ds_descrip = ''' + ISNULL(@c_ds_descrip, '') + ''',
							@id_fac_factura = @NewFacId,
							@id_fac_remision = @NewRmId,
							@id_CotizacionServicios = NULL,
							@in_nacionalidad = ' + CAST(@c_in_nacionalidad AS VARCHAR) + ',
							@cd_cencosto = ''' + ISNULL(@c_cd_cencosto, '') + ''',
							@cd_auxiliar = ''' + ISNULL(@c_cd_auxiliar, '') + ''',
							@cd_item = ''' + ISNULL(@c_cd_item, '') + ''',
							@id_tiposconceptfac = ' + ISNULL(CAST(@c_id_TiposConceptFac AS VARCHAR), 'NULL') + ',
							@id_conceptofacturacion = ' + ISNULL(CAST(@c_id_ConceptoFacturacion AS VARCHAR), 'NULL') + ',
							@id_tiposservicio = ' + ISNULL(CAST(@c_id_TiposServicio AS VARCHAR), 'NULL') + ',
							@cd_tiquete = ' + ISNULL('''' + @c_cd_tiquete + '''', 'NULL') + ',
							@id_voucherstocks = NULL,
							@cd_voucherPrefijo = NULL,
							@cd_proveedores = ''' + ISNULL(@c_cd_proveedores, '') + ''',
							@ds_tiposervnm = ''' + ISNULL(@c_ds_servicio, '') + ''',
							@cd_prov_hotel = NULL,
							@cd_prov_car = NULL,
							@cd_prov_air = NULL,
							@ds_servicio = ''' + ISNULL(@c_ds_servicio, '') + ''',
							@am_valorprov = ' + CAST(@c_Valor AS VARCHAR) + ',
							@id_monedaprov = ' + ISNULL(CAST(@id_monedas_iata AS VARCHAR), 'NULL') + ',
							@ds_InfoAdicional = NULL,
							@ds_paxname = ''' + ISNULL(@c_ds_paxname, '') + ''',
							@ds_paxape = ''' + ISNULL(@c_ds_paxape, '') + ''',
							@cd_paxtype = ''' + ISNULL(@c_cd_paxtype, '') + ''',
							@in_edad = NULL,
							@cd_voucher = NULL,
							@in_cantpax = 1,
							@dt_llegada = ' + ISNULL('''' + CONVERT(VARCHAR, @c_dt_llegada, 120) + '''', 'NULL') + ',
							@dt_salida = ' + ISNULL('''' + CONVERT(VARCHAR, @c_dt_salida, 120) + '''', 'NULL') + ',
							@ds_destino = NULL,
							@id_gds = NULL,
							@am_basecomisionable = ' + CAST(@c_Valor AS VARCHAR) + ',
							@am_porcomision = 0,
							@id_tipoplan = NULL,
							@id_acomodacion = NULL,
							@ds_paxClasificacion = NULL,
							@in_dias = NULL,
							@in_noches = NULL,
							@bl_notdomicilionacional = 0,
							@CodigoReserva = ''' + @c_CodigoReserva + ''',
							@AnticiposSqlStmt = NULL,
							@PaxAdicionalSqlStmt = NULL,
							@VoucherAdicionalSqlStmt = NULL,
							@id_monedas_iata = @id_monedas_iata,
							@Tcambio = @Tcambio,
							@Id_GrConcepto = NULL,
							@in_diasSrv = NULL,
							@in_nochesSrv = NULL,
							@OrdenGrabacion = 1,
							@Id_Especialista = NULL,
							@am_porcentaje_descuento = ' + CAST(ISNULL(@c_am_pordescuento, 0) AS VARCHAR) + ',
							@am_valor_descuento = 0,
							@ds_motivo_descuento = NULL,
							@Id_CargosDesc_Descuento = NULL,
							@dt_FechaSalidaSrv = ' + ISNULL('''' + CONVERT(VARCHAR, @c_dt_llegada, 120) + '''', 'NULL') + ',
							@dt_FechaLlegadaSrv = ' + ISNULL('''' + CONVERT(VARCHAR, @c_dt_salida, 120) + '''', 'NULL') + ',
							@cd_localizador = ''' + @c_CodigoReserva + ''',
							@cd_VoucherPax = NULL,
							@am_basecomisionableprov = ' + CAST(@c_Valor AS VARCHAR) + ',
							@am_porcomisionprov = 0,
							@cd_NumeFac = NULL,
							@dt_VenceFac = NULL,
							@Id_AcomodacionSrv = NULL,
							@Id_TipoPlanSrv = NULL,
							@in_habitaciones = NULL,
							@in_habitacionesSrv = NULL,
							@SqlStmt = ''' + REPLACE(@SrvSqlStmt, '''', '''''') + ''',
							@cd_Consecutivo_variablesadicionales = NULL,
							@cd_confirmacion = NULL,
							@ds_confirmadopor = NULL,
							@cd_paxidentificacion = NULL,
							@bl_politicaCancelacion = NULL,
							@dt_politicaCancelacion = NULL,
							@id_tipoHabitacion = NULL,
							@cd_Consecutivo_depende = ' + ISNULL('''' + @c_cd_Consecutivo_depende + '''', 'NULL') + ',
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
							@id_TipoServicio = ' + ISNULL(CAST(@c_id_TiposServicio AS VARCHAR), 'NULL') + ',
							@id_Aerolinea = NULL,
							@am_PorFacParcial = 100,
							@ds_GDS = NULL,
							@am_basedescuento = ' + CAST(ISNULL(@c_am_basedescuento, 0) AS VARCHAR) + ',
							@am_pordescuento = ' + CAST(ISNULL(@c_am_pordescuento, 0) AS VARCHAR) + '; '
					END

					SET @ItemIndex = @ItemIndex + 1;
					FETCH NEXT FROM curConcepts INTO 
						@c_id_ConceptoFacturacion, @c_cd_ConceptoFacturacion, @c_ds_ConceptoFacturacion, @c_id_TiposConceptFac, @c_bl_contorlarCargImp, @c_bl_CalculoAutoValoresFacturacion, @c_id_TiposServicio, @c_cd_TiposServicio, @c_ds_TiposServicio, @c_cd_proveedores, @c_ds_proveedores, @c_cd_tiquete, @c_ds_servicio, @c_ds_descrip, @c_ds_paxname, @c_ds_paxape, @c_cd_paxtype, @c_ds_paxClasificacion, @c_in_nacionalidad, @c_dt_llegada, @c_dt_salida, @c_cd_cencosto, @c_cd_auxiliar, @c_cd_item, @c_Valor, @c_am_Contado, @c_am_Credito, @c_ColId, @c_cd_Consecutivo_depende, @c_CodigoReserva, @c_am_ImpuestoComision, @c_Respuesta, @c_bl_RutaExentaIva, @c_id_FormasPago, @c_id_TarjetasCredito, @c_am_basedescuento, @c_am_pordescuento, @c_id_FormasPagoAirPlus, @c_cd_FormasPagoAirPlus, @c_ds_FormasPagoAirPlus, @c_id_TarjetasCreditoAirPlus, @c_cd_TarjetasCreditoAirPlus, @c_ds_numerotarjetaAirPlus;
				END;

				CLOSE curConcepts;
				DEALLOCATE curConcepts;

				-- Execute spza_Factura_Crear inside a TRY CATCH
				SET @FacturaRespuesta = NULL;
				SET @FacturaEstado = NULL;

				BEGIN TRY
					DECLARE @ReturnCode INT;
					
					EXEC @ReturnCode = dbo.spza_FacturaJOB_Crear
						@id_usuario = 1,
						@id_sucursal = @id_sucursal,
						@id_implante = @id_implante,
						@dt_fechacont = @FechaCont,
						@dt_vence = @FechaCont,
						@cd_tercero_codigo = @cd_cliente,
						@ds_tercero_nombre = @ds_cliname,
						@cd_cliente_codigo = @cd_cliente,
						@ds_cliente_nombre = @ds_cliname,
						@ds_cliente_dir = @ds_clidir,
						@ds_cliente_ciudad = @ds_clicity,
						@ds_cliente_tel = @ds_clitel,
						@ds_cliente_dirdesp = @ds_clidir,
						@ds_cliente_email = @ds_ClienteEmail,
						@ds_cliente_contacto = @ds_cliname,
						@ds_cliente_contacto_email = @ds_ClienteEmail,
						@id_monedas_iata = @id_monedas_iata,
						@cd_vendedor = @cd_vendedor,
						@id_tiqueteador = @id_tiqueteador,
						@bn_anexo = NULL,
						@Tcambio = @am_TasaCambio,
						@am_tcambiousd = @am_tcambiousd,
						@id_tipoventa = @id_tipoventa,
						@ds_num_resolucion = '',
						@in_num_inicial = 0,
						@in_num_final = 0,
						@ds_numeracion_autorizada = NULL,
						@dt_fecha_resolucion = NULL,
						@CodigoArchivoFisico = '',
						@ds_Observacion = @ds_Observaciones,
						@ds_Campo_libre1 = NULL,
						@ds_Campo_libre2 = NULL,
						@cd_fuente_Reemplaza = NULL,
						@cd_serie_Reemplaza = NULL,
						@cd_consecutivo_Reemplaza = NULL,
						@ds_Actividad_Economica = NULL,
						@ds_Tarifa_ICA = NULL,
						@SqlStmt = @SqlStmt,
						@AnticiposSqlStmt = NULL,
						@TotalFactura = @ValorFactura,
						@TotalCupoCreditoCliente = 0,
						@bl_BloqueoCupoCredito = 0,
						@bl_generadaauto = 1,
						@ds_CotizacionesId = NULL,
						@Id_Cierre = NULL,
						@cd_TipoFact = NULL,
						@id_fac_remisionRelacionada = NULL,
						@id_fac_facturaRelacionada = NULL,
						@ds_DescripcionFac = @ds_descripcion,
						@bl_nocont = 0,
						@ProductosSqlStmt = NULL,
						@cd_CF_TipoComprobante = NULL,
						@id_Licitacion = @cd_licitacion,
						@ValorFactura = @ValorFactura,
						@id_Especialista = NULL,
						@id_tiqueteador_Facturador = NULL,
						@id_TipoFormaPagoProveedor = NULL,
						@id_MedioReservacion = NULL,
						@bl_refacturacion = 0,
						@bl_comisiona = 0,
						@cd_fuente_factura = NULL,
						@cd_serie_factura = NULL,
						@cd_consecutivo_factura = NULL,
						@id_NotasAerolinea = NULL,
						@bl_interface = 0,
						@id_evento = NULL,
						@bl_NoEnviarFacElectronica = 0,
						@bl_DescontarComisionCxP = 0,
						@ds_num_resolucion_Adicional = '',
						@id_fac_facturaRefacturacion = NULL,
						@bl_refacturacion_contabilizar_saldos = 0,
						@ZML_VariablesXML = NULL,
						@bl_FormatoResumidoFactElectro = 0,
						@bl_ExigeAdjuntoFactElectro = 0,
						@bl_omitir_Validar_IVA_facturacion = 0,
						@ZML_AjusteIvaXML = NULL,
						@ds_RespuestaJOB = @FacturaRespuesta OUTPUT;

					IF @ReturnCode = 0
					BEGIN
						SET @FacturaEstado = 0;
					END
					ELSE
					BEGIN
						SET @FacturaEstado = 1;
						-- @FacturaRespuesta ya contiene el mensaje de error que devolvió el procedimiento
					END
				END TRY
				BEGIN CATCH
					SET @FacturaEstado = 1;
					SET @FacturaRespuesta = ERROR_MESSAGE();
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
