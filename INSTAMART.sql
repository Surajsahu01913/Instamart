

CREATE DATABASE INSTAMART;
USE INSTAMART ; 

SELECT * FROM [dbo].[address]
SELECT * FROM [dbo].[customers]
SELECT * FROM [dbo].[categories]
SELECT * FROM [dbo].[delivery_partners]
SELECT * FROM [dbo].[order_transactions]
SELECT * FROM [dbo].[payment_methods]
SELECT * FROM [dbo].[products]
SELECT * FROM [dbo].[stores]
SELECT * FROM [dbo].[suppliers]

CREATE VIEW VW_Full_Details
AS (
SELECT address.AddressID,address.Pincode,address.StateName,address.CityName,address.StreetAddress,
customers.CustomerID,customers.CustomerName,customers.CustomerSegment,customers.Email,customers.phone AS customers_Phone,
customers.RegistrationDate,OG.OrderID,OG.OrderDate,OG.DeliveryDate,OG.DeliveryPartnerID,OG.DiscountApplied,
OG.Quantity,OG.TotalPrice,OG.TimeOfDay,OG.ProductID,OG.OrderStatus,products.ProductName,products.StockQuantity,
products.UnitPrice,products.SupplierID,products.CategoryID,DL.PartnerName,DL.HireDate,DL.Phone AS DeliveryPartner_Phone ,
PAY.PaymentMethodName,CA.CategoryName,CA.Subcategory,suppliers.SupplierName,suppliers.ContactEmail
FROM [address]
JOIN customers  ON address.AddressID = customers.AddressID
FULL JOIN order_transactions AS OG  ON customers.CustomerID = OG.CustomerID
FULL JOIN products ON OG.ProductID = products.ProductID
FULL JOIN delivery_partners  AS DL ON DL.DeliveryPartnerID=OG.DeliveryPartnerID
FULL JOIN payment_methods AS PAY ON PAY.PaymentMethodID = OG.PaymentMethodID
FULL JOIN categories AS CA ON CA.CategoryID = products.CategoryID
JOIN suppliers ON products.SupplierID = suppliers.SupplierID )

SELECT * FROM VW_Full_Details 
--✨✨✨✨✨✨✨✨ UPDATE TOTAL PRICE ✨✨✨✨✨✨✨✨
UPDATE OT
SET OT.TotalPrice = OT.Quantity * P.UnitPrice
FROM order_transactions OT
JOIN products P ON OT.ProductID = P.ProductID;

--✨✨✨✨✨✨✨✨TOTAL Customers--[50] ✨✨✨✨✨✨✨✨
SELECT COUNT(DISTINCT(CustomerID)) AS Total_Customers
FROM customers
--✨✨✨✨✨✨✨✨ TOTAL ORDERS----[841]✨✨✨✨✨✨✨✨
SELECT COUNT(DISTINCT(OrderID)) AS Total_Customers
FROM order_transactions

--✨✨✨✨✨✨✨✨  SET FINAL PRICE APPLIED OFFER ✨✨✨✨✨✨✨✨
ALTER TABLE order_transactions
ADD Final_Price INT ;

UPDATE order_transactions
SET Final_Price = CASE 
WHEN (TotalPrice - DiscountApplied) <0 THEN 0 
ELSE (TotalPrice - DiscountApplied)
END ; 



--✨✨✨✨✨✨✨✨SUM OF (Befor & after DiscountApplied Price ) BY CUSTOMERS ✨✨✨✨✨✨✨✨
CREATE FUNCTION UDF_Costomer_Spent( @NAME VARCHAR (100))
RETURNS TABLE 
AS RETURN(
WITH TOTAL_PRICE AS (
SELECT CU.CustomerID, CU.CustomerName,SUM (OD.TotalPrice) AS Befor_DiscountApplied_Price,
(SUM (OD.TotalPrice)-SUM(OD.Final_Price) )AS Discount_Amount,
SUM(OD.Final_Price) AS FINALPRICE_After_AppliedDiscount
FROM order_transactions AS OD 
FULL JOIN customers AS CU ON CU.CustomerID = OD.CustomerID
GROUP BY CU.CustomerID,CU.CustomerName
),
Delivered AS (
SELECT CU.CustomerID,SUM(OD.Final_Price) AS Delivered_Orders_After_AppliedDiscount
FROM order_transactions AS OD 
FULL JOIN customers AS CU ON CU.CustomerID =OD.CustomerID
WHERE OD.OrderStatus = 'Delivered'
GROUP BY CU.CustomerID
),
Cancelled AS (
SELECT CU.CustomerID,SUM(OD.Final_Price) AS Cancelled_Orders_After_AppliedDiscount
FROM order_transactions AS OD 
FULL JOIN customers AS CU ON CU.CustomerID =OD.CustomerID
WHERE OD.OrderStatus = 'Cancelled'
GROUP BY CU.CustomerID
 ) ,
Returned AS (
SELECT CU.CustomerID,SUM(OD.Final_Price) AS Returned_Orders_After_AppliedDiscount
FROM order_transactions AS OD 
FULL JOIN customers AS CU ON CU.CustomerID =OD.CustomerID
WHERE OD.OrderStatus = 'Returned'
GROUP BY CU.CustomerID
)

SELECT TP.CustomerID,TP.CustomerName ,
ISNULL(TP.Befor_DiscountApplied_Price,0)AS B_Discount_Price$,
ISNULL(TP.Discount_Amount,0) AS Discount_Amount$,
ISNULL (TP.FINALPRICE_After_AppliedDiscount,0) AS FINALPRICE_After_AppliedDiscount , 
ISNULL(DD.Delivered_Orders_After_AppliedDiscount,0) AS  Total_Spent$,
ISNULL(CD.Cancelled_Orders_After_AppliedDiscount,0) Cancelled_Price$,
ISNULL(RD.Returned_Orders_After_AppliedDiscount,0) Returned_Price$
FROM TOTAL_PRICE AS TP
LEFT JOIN Delivered AS DD ON DD.CustomerID = TP.CustomerID
LEFT JOIN Cancelled AS CD ON CD.CustomerID = TP.CustomerID
LEFT JOIN Returned AS RD ON RD.CustomerID = TP.CustomerID
WHERE TP.CustomerID = @NAME OR TP.CustomerName = @NAME );

---Customer Total Spent ----------------------------

SELECT * FROM UDF_Costomer_Spent('CUST0001')---> INPUT 'CUST00xx'(1 TO 50 )




-->💀💀💀💀💀💀💀💀💀💀💀💀💀💀💀💀💀💀💀💀💀💀💀💀💀💀💀💀💀💀💀💀💀💀💀💀💀💀💀💀--
CREATE FUNCTION  UDF_ORDER_STATUS( @YEAR INT)
RETURNS TABLE 
AS RETURN(

WITH 
TOTAL_ORDERS AS 
(SELECT YEAR (OD.OrderDate ) AS YEARS ,
		MONTH (OD.OrderDate) AS MONTHS_NUMBER,
		FORMAT(OD.OrderDate,'MMMM') AS MONTH_NAME,
	COUNT(OD.OrderID)  AS TOTAL_ORDERS
FROM customers AS CU 
JOIN order_transactions AS OD ON OD.CustomerID = CU.CustomerID
GROUP BY YEAR (OD.OrderDate ),
		MONTH (OD.OrderDate),
		FORMAT(OD.OrderDate,'MMMM')
		),
ORDER_STATUS1 AS --<-----------------------------
(SELECT YEAR (OD.OrderDate ) AS YEARS ,
		MONTH (OD.OrderDate) AS MONTHS_NUMBER,
		FORMAT(OD.OrderDate,'MMMM') AS MONTH_NAME,
	  COUNT(OD.OrderID)  AS Delivered_Orders
      FROM order_transactions AS OD 
	  WHERE OrderStatus = 'Delivered'
GROUP BY YEAR (OD.OrderDate ),
		MONTH (OD.OrderDate),
		FORMAT(OD.OrderDate,'MMMM')
		),
		ORDER_STATUS2 AS --<------------------------
(SELECT YEAR (OD.OrderDate ) AS YEARS ,
		MONTH (OD.OrderDate) AS MONTHS_NUMBER,
		FORMAT(OD.OrderDate,'MMMM') AS MONTH_NAME,
	  COUNT(OD.OrderID)  AS Cancelled_Orders
      FROM order_transactions AS OD 
	  WHERE OrderStatus = 'Cancelled'
GROUP BY YEAR (OD.OrderDate ),
		MONTH (OD.OrderDate),
		FORMAT(OD.OrderDate,'MMMM')
		),
		ORDER_STATUS3 AS    --<------------------------
(SELECT YEAR (OD.OrderDate ) AS YEARS ,
		MONTH (OD.OrderDate) AS MONTHS_NUMBER,
		FORMAT(OD.OrderDate,'MMMM') AS MONTH_NAME,
	  COUNT(OD.OrderID)  AS Returned_Orders
      FROM order_transactions AS OD 
	  WHERE OrderStatus = 'Returned'
GROUP BY YEAR (OD.OrderDate ),
		MONTH (OD.OrderDate),
		FORMAT(OD.OrderDate,'MMMM')
		),
		ORDER_STATUS4 AS   --<------------------------
(SELECT YEAR (OD.OrderDate ) AS YEARS ,
		MONTH (OD.OrderDate) AS MONTHS_NUMBER,
		FORMAT(OD.OrderDate,'MMMM') AS MONTH_NAME,
	  COUNT(OD.OrderID)  AS Shipped_Orders
      FROM order_transactions AS OD 
	  WHERE OrderStatus = 'Shipped'
GROUP BY YEAR (OD.OrderDate ),
		MONTH (OD.OrderDate),
		FORMAT(OD.OrderDate,'MMMM')
		),
		ORDER_STATUS5 AS   --<------------------------
(SELECT YEAR (OD.OrderDate ) AS YEARS ,
		MONTH (OD.OrderDate) AS MONTHS_NUMBER,
		FORMAT(OD.OrderDate,'MMMM') AS MONTH_NAME,
	  COUNT(OD.OrderID)  AS Pending_Orders
      FROM order_transactions AS OD 
	  WHERE OrderStatus = 'Pending'
GROUP BY YEAR (OD.OrderDate ),
		MONTH (OD.OrderDate),
		FORMAT(OD.OrderDate,'MMMM')
		)

SELECT TR.YEARS,TR.MONTHS_NUMBER,TR.MONTH_NAME,
ISNULL(TR.TOTAL_ORDERS,0) AS TOTAL_ORDERS , 
ISNULL(OS1.Delivered_Orders,0) AS Delivered_Orders,
ISNULL(OS2.Cancelled_Orders,0) AS Cancelled_Orders,
ISNULL(OS3.Returned_Orders,0) AS Returned_Orders,
ISNULL(OS4.Shipped_Orders,0) AS Shipped_Orders,
ISNULL(OS5.Pending_Orders,0) AS Pending_Orders
FROM TOTAL_ORDERS AS TR
LEFT JOIN ORDER_STATUS1 AS OS1 ON TR.YEARS = OS1.YEARS AND TR.MONTH_NAME = OS1.MONTH_NAME
LEFT JOIN ORDER_STATUS2 AS OS2 ON TR.YEARS = OS2.YEARS AND TR.MONTH_NAME = OS2.MONTH_NAME
LEFT JOIN ORDER_STATUS3 AS OS3 ON TR.YEARS = OS3.YEARS AND TR.MONTH_NAME = OS3.MONTH_NAME
LEFT JOIN ORDER_STATUS4 AS OS4 ON TR.YEARS = OS4.YEARS AND TR.MONTH_NAME = OS4.MONTH_NAME
LEFT JOIN ORDER_STATUS5 AS OS5 ON TR.YEARS = OS5.YEARS AND TR.MONTH_NAME = OS5.MONTH_NAME
WHERE TR.YEARS = @YEAR ) ; 
------💀💀💀💀 Do not select the above text 💀💀💀💀--------------------------------------------------------
---TOTAL ORDERS STATUS YEAR WISE >-⌚-------------------

SELECT *
FROM dbo.UDF_ORDER_STATUS(2025) ---> INPUT (2024,2025)
ORDER BY MONTHS_NUMBER ASC;

--✨✨✨✨✨✨✨✨✨✨✨✨✨✨✨✨✨✨✨✨✨✨✨✨✨✨✨✨✨✨✨✨✨✨✨✨✨✨✨✨✨✨✨✨✨✨✨✨✨✨✨✨✨✨✨✨
		
------ TOTAL NUMBER OF ORDERS BY CUSTOMER----------
WITH CUSTOMER AS (
SELECT DISTINCT (CU.CustomerID ),COUNT(OD.OrderID) AS TOTAL_ORDERS
FROM order_transactions AS OD 
FULL JOIN customers AS CU  ON CU.CustomerID = OD.CustomerID
GROUP BY CU.CustomerID ),
Delivered AS (
SELECT DISTINCT (CU.CustomerID ),COUNT(OD.OrderID) AS Delivered_ORDERS
FROM order_transactions AS OD 
FULL JOIN customers AS CU  ON CU.CustomerID = OD.CustomerID
WHERE OD.OrderStatus = 'Delivered'
GROUP BY CU.CustomerID )

SELECT CU.CustomerID,
ISNULL(CU.TOTAL_ORDERS,0) AS TOTAL_ORDERS ,
ISNULL(DL.Delivered_ORDERS,0) AS Delivered_ORDERS
FROM CUSTOMER  AS CU 
LEFT JOIN Delivered AS DL ON DL.CustomerID = CU.CustomerID

---------------------------------------------------------

SELECT * FROM VW_Full_Details 


SELECT SUM(Quantity) AS Total_orders_Delivered
FROM order_transactions
WHERE OrderStatus = 'Delivered'

SELECT SUM(Quantity) AS Total_orders_Delivered
FROM order_transactions



SELECT COUNT(DeliveryPartnerID)
FROM [dbo].[order_transactions]
GROUP BY DeliveryPartnerID



select top 5 
ad.StateName ,sum(ot.Quantity),sum(ot.TotalPrice)
from [dbo].[order_transactions] as ot 
full join [dbo].[customers] as cu on ot.CustomerID = cu.CustomerID
join [dbo].[address] as ad on ad.AddressID = cu.AddressID
group by StateName 
order by sum(ot.TotalPrice) desc