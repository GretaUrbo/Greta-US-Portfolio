

/*

Scenario 4: Regional Sales Performance for Expansion Strategy

AdventureWorks wants to identify which regions show the highest sales performance as part of an expansion strategy. 
Your students are tasked with finding the most profitable regions and understanding key factors behind regional performance.

Task 1: Extract sales data by region for the past two years.
Task 2: Calculate total revenue and year-over-year growth per region.
Task 3: Identify top products contributing to sales in each region.
Task 4: Analyze customer demographics within each region.
Task 5: Rank regions by profitability and sales growth.
Task 6: Recommend regions for potential expansion, citing reasons based on sales trends and demographic analysis.

*/

/* Task 1: Extract sales data by region for the past two years.*/


/* First, I created a temporary table called salesOrders, where I will store more detailed sales data, 
   which I will later use in further analysis */

create temporary table salesOrders AS
SELECT h.SalesOrderID, 
		h.customerId, 
        CASE
        WHEN t.CountryRegionCode LIKE 'US' THEN CONCAT('USA, ', t.Name)
        ELSE t.Name
        END as Region,
        t.CountryRegionCode,
        d.productId,
        p.Name as ProductName,
        sub.name as Subcategory,
        cat.name as Category,
        d.unitPrice, 
        d.orderQty, 
        d.LineTotal,
        h.OrderDate
FROM sales_salesorderheader h
LEFT JOIN sales_salesorderdetail d ON d.SalesOrderID = h.SalesOrderID
LEFT JOIN sales_salesterritory t ON t.TerritoryID = h.territoryID
LEFT JOIN production_product p ON p.productID = d.productID
LEFT JOIN production_productsubcategory sub ON sub.ProductSubcategoryID = p.ProductSubcategoryID
LEFT JOIN production_productcategory cat ON cat.ProductCategoryID = sub.ProductCategoryID
ORDER BY Region;

/* Then, using the previously created temporary table, a brief overview of the turnover in different regions over the past two years is performed.
We can see that most sales occurred in the western USA regions, as well as in Canada and Australia.
The least sales were made in the eastern USA regions and in Germany */

SELECT Region, round(sum(LineTotal),0) as totalRevenue
FROM salesOrders
WHERE OrderDate >= (SELECT date_sub(max(OrderDate), INTERVAL 2 YEAR) FROM sales_salesorderheader)
GROUP BY Region
ORDER BY totalRevenue desc;



/* Task 2: Calculate total revenue and year-over-year growth per region.*/


/* The market sales growth is calculated in percentage points by comparing each year. It may appear that in 2014 all regions experienced a decline in sales, 
but I want to emphasize that the 2014 data in the database is incomplete, 
which significantly affected the results.
In most cases, 2013 is the most representative year, as it was compared to the full year of 2012,
whereas 2012 was compared to 2011 — a year that was the first year of operation in almost all regions 
and was also incomplete */


with totalRevenuePerRegionPerYear AS (
SELECT YEAR(OrderDate)as year, Region, round(sum(LineTotal),2) as totalRevenue
FROM salesOrders
GROUP BY region, year)

SELECT *, round(lag(totalRevenue) OVER (partition by Region Order by year),2) as revenueYearBefore, 
CASE
	WHEN totalRevenue <= lag(totalRevenue) OVER (partition by Region Order by year) 
    THEN CONCAT('-', round(totalRevenue/(lag(totalRevenue) OVER (partition by Region Order by year))*100,2),' %')
    ELSE CONCAT('+',round(totalRevenue/(lag(totalRevenue) OVER (partition by Region Order by year))*100,2), ' %')
END as Growth
FROM totalRevenuePerRegionPerYear;


/* Task 3: Identify top products contributing to sales in each region. */

/* Calculate the top 5 products in each region 
   based on the number of units sold */

with productsSoldByRegion AS (
SELECT Region, ProductId, ProductName, Category, SUM(orderQty) as productsSold
FROM salesOrders
GROUP BY ProductId, ProductName, Region, Category),
rankedProducts AS (
SELECT *, DENSE_RANK() OVER (PARTITION BY Region ORDER BY productsSold desc) as topProducts
FROM productsSoldByRegion)

SELECT *
FROM rankedProducts
WHERE topProducts<=5;

 
 /* It is also possible to analyze from a different perspective — not by the number of units sold,
   but by sales revenue. That is, which products generated the highest revenue.
   The following query selects the top 5 products in each region based on revenue.
   We can see that the results are completely different — the highest revenue-generating products 
   in all regions are bicycles. They are sold in smaller quantities, but they are much more expensive.
   On the other hand, in the analysis based on units sold, accessories and clothing dominate — 
   items that cycling enthusiasts buy more frequently and replace often, 
   but in terms of revenue, they are not the top earners */


with topProductsByRevenueByRegion AS (
SELECT Region, productId, ProductName, Category, sum(LineTotal) as revenue
FROM salesOrders
GROUP BY Region, productId, ProductName, Category),
rankedProducts AS (
SELECT *, DENSE_RANK() OVER (PARTITION BY Region ORDER BY revenue desc) as topProducts
FROM topProductsByRevenueByRegion)

SELECT *
FROM rankedProducts
WHERE topProducts<=5;


/* Task 4: Analyze customer demographics within each region.*/

/* First, I created a temporary table to store information about customers who made purchases, 
   as well as data extracted from the customer survey.
   I did this to avoid repeating code when analyzing individual demographic indicators */

create temporary table customerDemographics as
SELECT distinct o.customerId, o.OrderDate, o.Region, SUBSTRING(
	p.Demographics, LOCATE('<birthDate>', p.Demographics) + LENGTH('<birthDate>'),
     LOCATE('</birthDate>', p.Demographics)-(LOCATE('<BirthDate>', p.Demographics)+length('<BirthDate>')+1)) as birthDate,
    SUBSTRING(
	p.Demographics, LOCATE('<YearlyIncome>', p.Demographics) + LENGTH('<YearlyIncome>'),
    LOCATE('</YearlyIncome>', p.Demographics)-(LOCATE('<YearlyIncome>', p.Demographics)+length('<YearlyIncome>'))) as Income,
    SUBSTRING(
	p.Demographics, LOCATE('<Gender>', p.Demographics) + LENGTH('<Gender>'),
    LOCATE('</Gender>', p.Demographics)-(LOCATE('<Gender>', p.Demographics)+length('<Gender>'))) as Gender,
    SUBSTRING(p.Demographics, LOCATE('<Education>', p.Demographics)+length('<Education>'),
    LOCATE('</Education>', p.Demographics)-(LOCATE('<Education>',p.Demographics)+length('<Education>'))) as Education
FROM salesorders o
LEFT JOIN sales_customer c ON c.customerId=o.customerId
LEFT JOIN person_person p ON p.BusinessEntityID = c.personID
;

DROP temporary table customerDemographics;


/* In the next section, the customer composition across different regions is analyzed based on buyers' age.
   In all regions, the average buyer age is very similar — between 50 and 53 years.
   The buyer's age was calculated assuming that the survey was conducted shortly after the purchase, 
   so the calculation used OrderDate and Birthdate */

SELECT Region, ROUND(AVG(YEAR(OrderDate)-YEAR(birthDate)),0) as Age
FROM customerDemographics
GROUP BY Region
ORDER BY Age desc;


/* The proportion of customers by gender is calculated for each region.
   We can see that in almost all regions, the share of female (F) and male (M) customers 
   is quite similar, with the exception of the eastern USA regions, 
   where the proportion of female customers is significantly lower than that of male customers */

SELECT Region, Gender, CONCAT(ROUND(count(customerId)/sum(count(customerID)) OVER (partition by Region)*100, 2), '%') AS GenderPercentage
FROM customerDemographics
WHERE Gender LIKE 'M' OR Gender LIKE 'F'
GROUP BY Region, Gender
;

/* Next, the proportion of customers by education level is calculated.
   As we can see, the Australia region stands out significantly, 
   with the majority of customers holding a bachelor's degree or higher.
   Also notable is the USA Central region, which has a high percentage of customers with higher education */

SELECT Region, Education, CONCAT(ROUND(count(customerId)/sum(count(customerID)) OVER (partition by Region)*100, 2), '%') AS EducationPercentage
FROM customerDemographics
WHERE Education != ''
GROUP BY Region, Education
;

/* Next, an analysis is performed based on customer income and regions.
   Again, Australia stands out, where the majority of customers have annual incomes greater than 50,000.
   If we consider 50,000 as an average income benchmark, then France stands out with lower customer incomes.
   Additionally, compared to the USA or Australia, European customers generally have lower incomes overall. */

SELECT Region, Income, CONCAT(ROUND(count(customerId)/sum(count(customerID)) OVER (partition by Region)*100, 2), '%') AS IncomePercentage
FROM customerDemographics
WHERE Income != ''
GROUP BY Region, Income
;


/* Task 5: Rank regions by profitability and sales growth.*/

/* Since regional sales do not necessarily correlate with growth, 
   I initially analyzed these parameters separately.
   First, I created a temporary table named ranking_by_profitability, 
   where regions are ranked based on sales */
   
CREATE temporary table ranking_by_profitability AS
with revenueByRegion AS (
SELECT Region, SUM(LineTotal) as revenue
FROM salesOrders
GROUP BY Region)
SELECT *, RANK() OVER (ORDER BY revenue desc) as RankingByRevenue
FROM revenueByRegion;

/* Then, a second temporary table named ranking_by_growth was created, 
   which ranks the regions based on absolute growth — that is, I calculated the absolute sales growth.
   Since the data for the first and last years (let's assume they're "current" years) is incomplete, 
   to minimize distortion caused by missing time periods, I first broke down sales by month.
   I then compared the first year that has data for a given quarter 
   with the most recent year that also has data for that same quarter.
   Afterward, I summed the absolute growth for all quarters in each region 
   and compared those total values */

CREATE temporary table ranking_by_growth AS
with totalRevenuePerRegionPerYear AS (
SELECT YEAR(OrderDate)as year, month(OrderDate) as month, Region, round(sum(LineTotal),2) as totalRevenue,
ROW_NUMBER() OVER (PARTITION BY Region, month(OrderDate) ORDER BY YEAR(OrderDate) asc) as firstYear,
ROW_NUMBER() OVER (PARTITION BY Region, month(OrderDate) ORDER BY YEAR(OrderDate) desc) as lastYear 
FROM salesOrders
GROUP BY region, year, month),
monthGrowth as (SELECT *, LEAD(totalRevenue) OVER(partition by region, month order by year) - totalRevenue as MonthGrowth
FROM totalRevenuePerRegionPerYear
WHERE firstYear = 1 OR lastYear = 1)
SELECT Region, sum(MonthGrowth) as AbsoluteGrowth, RANK() OVER(order by sum(MonthGrowth) desc) as RankingByGrowth
FROM monthGrowth
GROUP BY Region;


DROP temporary table ranking_by_growth;

/* In the final section, I joined both temporary tables to enable a quick overview 
   and identify markets with high potential.
   For example, we can clearly see that the USA Southwest region is already the top-performing region in terms of sales, 
   while also showing strong absolute growth.
   Meanwhile, the United Kingdom is only in seventh place by sales, 
   but it shows considerable growth potential */
   
SELECT p.Region, p.RankingByRevenue, g.RankingByGrowth
FROM ranking_by_profitability p
JOIN ranking_by_growth g ON p.region = g.region
ORDER BY g.RankingByGrowth;




/*Task 6: Recommend regions for potential expansion, citing reasons based on sales trends and 
demographic analysis.
*/

/* Undoubtedly, there is significant potential in the USA West regions, considering sales trends, growth, and customer income levels.
Australia also stands out with strong current performance, steady growth, and favorable population purchasing power.

Although European regions — the UK, France, and Germany — may at first glance seem less attractive for expansion due to lower customer incomes and sales revenue compared to other regions, their growth figures are promising.
These markets may hold substantial potential due to well-developed cycling infrastructure and cultural habits.
Lower income levels in this context might even drive growth — individuals with lower incomes could be more inclined to invest in bicycles as a mode of transportation than higher-income individuals.
This is a sector where customer income and sales potential do not necessarily correlate.

Another concern is the relatively high average age of buyers across all regions.
The company may need to reconsider its marketing strategy and review its product range in order to attract younger customers.
*/




