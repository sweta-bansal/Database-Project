
*********Part 2a****************

create table items(
	item varchar(20),
	unitWeight integer,
	primary key (item)
);

create table busEntities(
	entity varchar(20),
	shipLoc varchar(20),
	address varchar(50),
	phone varchar(20),
	web varchar(50),
	contact varchar(20),
	primary key (entity)
);

create table billOfMaterials(
	prodItem varchar(20),
	matItem varchar(20),
	QtyMatPerItem integer,
	primary key (prodItem,matItem),
	foreign key (prodItem) references items (item),
	foreign key (matItem) references items (item)
);

create table supplierDiscounts(
	supplier varchar(20),
	amt1 decimal(8,4),
	disc1 decimal(3,2), 
	amt2 decimal(8,4),
	disc2 decimal(3,2),
	primary key (supplier),
	foreign key (supplier) references busEntities (entity)
);

create table supplyUnitPricing(
	supplier varchar(20), 
	item varchar(20),
	ppu integer,
	primary key (supplier,item),
	foreign key (supplier) references busEntities (entity),
	foreign key (item) references items
);

create table manufDiscounts(
	manuf varchar(20),
	amt1 decimal(8,4),
	disc1 decimal(3,2),
	primary key (manuf),
	foreign key (manuf) references busEntities (entity)
	
);

create table manufUnitPricing(
	manuf varchar(20),
	prodItem varchar(20),
	setUpCost integer,
	prodCostPerUnit integer,
	primary key(manuf,prodItem),
	foreign key (manuf) references busEntities (entity),
	foreign key (prodItem) references items 
);

create table shippingPricing(
	shipper varchar(20),
	fromLoc varchar(20),
	toLoc varchar(20),
	minPackagePrice integer,
	pricePerLb integer,
	amt1 integer,
	disc1 integer,
	amt2 integer,
	disc2 integer,
	primary key(shipper,fromLoc,toLoc),
	foreign key (shipper) references busEntities (entity)
);

create table customerDemand(
	customer varchar(20),
	item varchar(20),
	qty integer,
	primary key(customer,item),
	foreign key(item) references items,
	foreign key (customer) references busEntities (entity)
);

create table supplyOrders(
	item varchar(20),
	supplier varchar(20),
	qty integer,
	primary key(item,supplier),
	foreign key(item) references items,
	foreign key(supplier) references supplierDiscounts
);

create table manufOrders(
	item varchar(20),
	manuf varchar(20),
	qty integer,
	primary key(item,manuf),
	foreign key(item) references items,
	foreign key(manuf) references manufDiscounts
);

create table shipOrders(
	item varchar(20),
	shipper varchar(20),
	sender varchar(20),
	recipient varchar(20),
	qty integer,
	primary key(item, shipper, sender, recipient),
	foreign key(item) references items,
	foreign key(shipper) references busEntities (entity),
	foreign key (sender) references busEntities (entity),
	foreign key (recipient) references busEntities (entity)
);

******Part 2b***********

******1******

Drop View shippedVsCustDemand;
Create View shippedVsCustDemand AS
(
	Select C.customer, C.item, C.qty AS OrderedQty, COALESCE(SUM(S.qty),0) AS ShippedQty
	From customerDemand C, shipOrders S
	Where c.customer = S.recipient (+) AND C.Item = S.Item (+)
    Group by  C.customer, C.Item, C.qty
);
/* Totally Changed */

*******2******

drop view totalManufItems;
create view totalManufItems as 
(select item, COALESCE(SUM(qty),0) as total_qty
from manufOrders group by item);

*******3******
drop view shipped;
create view shipped as
(select item,recipient,COALESCE(sum(qty),0) as total_qty
from shipOrders
group by item,recipient);


Drop View matsUsedVsShipped ;
create view matsUsedVsShipped as 
(select m.item,m.manuf,b.matitem, b.QtyMatPerItem*m.qty as Required_Qty, COALESCE(s.total_qty,0) as Shipped_Qty
from manufOrders m, billOfMaterials b, shipped s
where m.item=b.prodItem and b.matItem=s.item(+) and m.manuf=s.recipient);
/* there should be 5 rows. manufacturer 3 is not being displayed */

*******4***********
drop view shippedout;
create view shippedout as
(select item,sender, COALESCE(sum(qty),0) as total_qty 
from shipOrders group by item,sender);

drop view producedVsShipped;
create view producedVsShipped as
(Select m.item, m.manuf, m.qty as Produced_Qty, COALESCE(so.total_qty,0) as Shipped_Qty
from manufOrders m, shippedout so
where m.manuf=so.sender (+) and m.item = so.item (+));
/* Minor Changes made */

select * from producedVsShipped;

*********5**********

Drop View suppliedVsShipped ;
create view suppliedVsShipped as 
(select so.supplier, so.item, so.qty as OrderedQty, COALESCE(sum(s.qty),0) as ShippedQty
from supplyOrders so, shipOrders s
where so.supplier=s.sender (+) and so.item=s.item (+)
Group By so.supplier, so.item, so.qty);
/* Minor Changes made */

********6**********
drop view suplier_itemcost;
create view suplier_itemcost as
(
select so.supplier,sum(so.qty*s.ppu) as total_cost
from supplyOrders so left join supplyUnitPricing s on so.item=s.item and so.supplier=s.supplier
group by so.supplier);

Drop View perSupplierCost;
create view perSupplierCost as
(
select sd.supplier, 
case when (s.total_cost>=sd.amt1 and s.total_cost<sd.amt2) then s.total_cost-s.total_cost*disc1
     when (s.total_cost>=sd.amt2) then s.total_cost-s.total_cost*disc2
     else s.total_cost
end as SupplierCost
from supplierDiscounts sd left join suplier_itemcost s on s.supplier=sd.supplier);

*********7**********
drop view manuf_peritemcost;
create view manuf_peritemcost as
(
select mo.manuf,mo.item, mu.setUpCost+mo.qty*mu.prodCostPerUnit as cost
from manufOrders mo, manufUnitPricing mu
where mo.manuf=mu.manuf (+) and mo.item=mu.prodItem (+)
Group By mo.manuf,mo.item,mu.setUpCost+mo.qty*mu.prodCostPerUnit);

Drop View manuf_totalitemcost;
create view manuf_totalitemcost as
(
select m.manuf, COALESCE(sum(m.cost),0) as total_cost
from manuf_peritemcost m
group by m.manuf
);

Drop View perManufCost;
create view perManufCost as
(
select md.manuf, 
case when (mt.total_cost>md.amt1) then mt.total_cost-mt.total_cost*md.disc1
     else mt.total_cost
end as totalManufCost
from manufDiscounts md left join manuf_totalitemcost mt on md.manuf=mt.manuf
);

**********8******

Drop View ItemShipLoc;
create view ItemShipLoc as
(
select s.item,s.shipper,b1.shipLoc as fromLoc,b2.shipLoc as toLoc, s.qty
from shipOrders s, busEntities b1, busEntities b2
where b1.entity=s.sender and b2.entity=s.recipient
);

Drop View ItemQty;
create view ItemQty as
(
select l.shipper,l.fromLoc,l.toLoc,l.item, l.qty*i.unitWeight as Item_Weight
from ItemShipLoc l,items i
where i.item=l.item
group by l.shipper,l.fromLoc,l.toLoc, l.item,  l.qty*i.unitWeight);


Drop View totalQty;
create view totalQty as
(
select l.shipper,l.fromLoc,l.toLoc,COALESCE(sum(l.Item_Weight),0) as totalWt
from ItemQty l
group by l.shipper,l.fromLoc,l.toLoc);
/* minor change made */

*********************l.totalWt*s.pricePerLb as total_cost*******

Drop View totalPrice;
create view totalPrice as
(
select s.shipper,s.fromLoc,s.toLoc,s.minPackagePrice, 
case when (l.totalWt*s.pricePerLb>=amt1 and l.totalWt*s.pricePerLb<=amt2) then l.totalWt*s.pricePerLb-l.totalWt*s.pricePerLb*disc1
     when (l.totalWt*s.pricePerLb>amt2) then l.totalWt*s.pricePerLb-l.totalWt*s.pricePerLb*disc2
     else l.totalWt*s.pricePerLb
end as PackagePrice
from shippingPricing s left join totalQty l on s.shipper=l.shipper and s.fromLoc=l.fromLoc and s.toLoc=l.toLoc);


Drop View MinPrice;
create view MinPrice as
(
select s.shipper,s.fromLoc,s.toLoc,
case when (s.minPackagePrice>s.PackagePrice) then s.minPackagePrice
     else s.PackagePrice
end as MinCost
from totalPrice s
);


Drop View perShipperCost;
create view perShipperCost as
(
select shipper, COALESCE(sum(MinCost),0) as TotalShippingCost
from MinPrice
group by shipper);
/* minor change made */

***********9***************

Drop View totalCostBreakdown;
create view totalCostBreakdown as
(
select totalSuppliercost, totalManufCost, totalShipperCost, totalSuppliercost+ totalManufCost+totalShipperCost as OverallCost 
from (select sum(TotalShippingCost) as totalShipperCost from perShipperCost),
(select sum(totalManufCost) as totalManufCost from perManufCost),
(select sum(SupplierCost) as totalSuppliercost from perSupplierCost)
);



*********Part 2c********************************************************************

**1**

Select distinct customer
from shippedVsCustDemand
where ShippedQty < OrderedQty;
/* Changes made */

**2**

select distinct supplier
from suppliedVsShipped
where ShippedQty < OrderedQty;
/* Changed comparison */

**3**

select distinct manuf 
from matsUsedVsShipped
where Shipped_Qty < Required_Qty;
/* Changed comparison */

**4**

select distinct manuf
from producedVsShipped
where Shipped_Qty<Produced_Qty;



