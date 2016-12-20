!---------------------------------------------------------------
!	Program DPDPOLYM.F90
!	using dissipative particle dynamics to simulate flow 
!	problems. The initial coordinates of wall and fluid 
!	were generated by "dpdconf.f90" and stored in file
!	"atoms.cnf"
!---------------------------------------------------------------
!  runId:
!  0 -- no flow, periodic BC in 3 directions
!  1 -- simple shear flow or Poiseuille Flow, wall BC in Z-direction
!  2 -- periodic Poiseuille flow for viscosity test, periodic BC in 3 directions
!  3 -- elongation flow, periodic BC in 3 directions
!  4 -- pipe flow
!  5 -- Wall bubble
!  6 -- acceleration Drag bubble
!  7 -- velocity Drag bubble
!  64 -- acceleration Drag bubble pipe flow
!  74 -- velocity Drag bubble pipe flow
!  8 -- dig a sphere gap to simulation bubble collpase without BC in 3 direction

    implicit none
    include 'dpdflow.h'
    
    !real*8	stime, rtime,second
    !integer hour,minute
!   character*50 inf, intcnf, out1, out2, out3, out4
    integer n, k
    integer drp1 !,stepOut
    
    
   !call getCPUtime(stime)
!   call getarg(1, inf)
!	call getarg(2, intcnf)
!	call getarg(3, out1)
!	call getarg(4, out2)
!	call getarg(5, out3)
!	call getarg(6, out4)

	inpt = 10
	lst1 = 11
	lst2 = 12 
	lst3 = 13 
	lst4 = 14
    lst5 = 15 
	lcnf = 16
    drp1 = 21
    forc = 91
    
    
    !inquire(file='./data/output/fluid1.dat',exist=filexist)
    !if(.not.filexist)call system('mkdir .\data\output')    
    
	open (unit = inpt, file = './data/config.dat', status = 'old')
	open (unit = lcnf, file = './data/initdpd.cnf')
	open (unit = lst1, file = './data/output/fluid1.dat', status = 'unknown')
	open (unit = lst2, file = './data/output/fluid2.dat', status = 'unknown')
    open (unit = lst3, file = './data/output/fluid3.dat', status = 'unknown')
	open (unit = lst4, file = './data/output/fluid4.dat', status = 'unknown')

	call readinitconf

    if(nDp .gt. 0) then
       open (unit = lst5, file = './data/output/droplet.dat', status = 'unknown')
       open (unit = forc, file = './data/output/CntForc.dat', status = 'unknown')
       open (unit = drp1, file = './data/dropconf.dat', status = 'unknown')
       read (drp1, *) 
       read (drp1, *) PstAdj, HPstAdj, stepFzn, stepStop !, cpct
       close(drp1)
    endif

	call InputData

	close(inpt)
!----------------------------------------------------------------------------    
   
!    write(*,*) 'input the stepCout number which you want to output the paticles locations'
 !   read(*,*) stepOut
    
    

    ! if (runID .eq. 5 .and. stepCount .eq. stepEquil) then
        !  call BottomWallConf
    !  endif
!------------------------------------------------------------------------------    

    if(runId .eq. 1) then
       nStartAtom = 1
       PNDIM = NDIM - 1
    !elseif(runId .eq. 4)then
    !    nStartAtom = 1
    !    PNDIM = 1        
    else
       nStartAtom = nWallAtom + 1
       PNDIM = NDIM
    endif
    
    
	call SetParams
    
	call SetupJob

	timeNow = 0.
	moreCycles = 1
    
    !-----------------------------------------------------------------------------------
    call readExtraPara			!read Extra parameters: 
                                !the RDFstepSample and deltaQ for RDF computation
                                !DiffintStep and DiffStep for diffusivity computation
    !print*,DiffintStep, DiffStep
    !pause
    !-----------------------------------------------------------------------------------
 
    do while (moreCycles .eq. 1)        
! Add special Boundary Condition ------------------------------------from AddBC.f90
        If (runId .eq. 1 .and. stepCount .gt. stepEquil) then	  
            do n = 1, nWallAtom
                if(r(n,3).lt.0.0) then
		            rv(n,1) = -shearRate*initUcell(3)/2*gap(3)
        !		    rv(n,1) =  shearRate*initUcell(3)/2*gap(3)
		        else
		            rv(n,1) =  shearRate*initUcell(3)/2*gap(3)
		        endif
	        enddo
        endif
            
          
        if (((runID .eq. 4) .or.(runID .eq. 64).or.(runID .eq. 74) ).and. stepCount .eq. stepEquil) then                                           
            call PipeAdd 
!          call ouptParticleSituation 
        endif
            
        if (runID .eq.5 .and. stepCount .eq. stepEquil) then                                           
            call MidPlaneAdd
            call ouptParticleSituation           
        endif
        
        if(runID .eq.8 .and.stepCount .eq. stepEquil*5) then                                           
                call DigCentreBubbleGap
                deltaT=deltaT/10
                call ouptParticleGap(0)
        endif
! Add special Boundary Condition --------------------------------------------------------------------------
! output the Particles situation -------------------------------------from Testool.f90
        if (stepCount==10) call ouptParticleSituation            
        if(stepCount > stepEquil)then
            if(stepCount <= 10000 .and.mod(stepCount,2000) .eq. 0) call ouptParticleSituation
            if(stepCount > 10000 .and.mod(stepCount,5000) .eq. 0) call ouptParticleSituation
        else
            if(mod(stepCount,stepEquil/3) .eq. 0) call ouptParticleSituation
        endif
        
        if(stepCount .ge. stepLimit) call ouptParticleSituation
            
        if (runID .eq.8 .and. stepCount .gt. stepEquil*5) then
            if(mod(stepCount-stepEquil,stepAvg) .eq. 0 .and. stepCount .lt. stepLimit) call ouptParticleGap(1)
            if(stepCount .ge. stepLimit) call ouptParticleGap(-1)
        endif
    
    
        if(stepCount .eq. 10) call ouptSameParticlesAvg(0) 
        if(mod(stepCount,stepAvg) .eq. 0 .and. stepCount .gt.0.and. stepCount .lt. stepLimit) call ouptSameParticlesAvg(1)  
        if(stepCount .ge. stepLimit) call ouptSameParticlesAvg(-1)

! output the Particles situation ----------------------------------------------------------------------------   


        !print*, stepCount
        
        call SingleStep
        
        if (nDp .eq. 1 .and. stepCount .ge. (stepLimit-RDFstepSample)) then
            !RDFstepSample = 10000
            if (stepCount .eq. (stepLimit-RDFstepSample)) call ouptRDF(0)
            if (stepCount .gt. (stepLimit-RDFstepSample)) call ouptRDF(1)
            if (stepCount .eq. stepLimit) call ouptRDF(2)
        endif
        !print*, stepCount
!         if (runID .eq.0 .and. stepCount .ge. (stepLimit-DiffStep)) then
!             !DiffintStep, DiffStep                    
!             if (stepCount .eq. (stepLimit-DiffStep)) call DiffusionCompute(0)
!             if (mod(stepCount-(stepLimit-DiffStep),DiffintStep) .eq. 0 .and. &
!                                  stepCount .gt. (stepLimit-DiffStep)) call DiffusionCompute(1)
!             if(stepCount .eq. stepLimit) call DiffusionCompute(2)
!         endif
! The Berendsen Barostat ----------------------------------------------------------------------------   
        !if(stepCount .ge. stepEquil) print*, stepCount

        if(stepCount .ge. stepEquil) call Barostat

        if(nDp .eq. 1 .and. stepCount .ge. stepEquil) call BubbleSize
     
	    if(stepCount .ge. stepLimit) moreCycles = 0

    enddo

      
	call GridAvChainProps(2)	
	call PrintChainLen
	
	!call getCPUtime(rtime)
 !   second=mod((rtime - stime),60.)
 !   minute=int(mod((rtime - stime-second),3600.)/60)
 !   hour=int((rtime - stime-second-60*minute)/3600)
 !   open(209, file = './data/log.dat')
	!write(209,'(''Total CPU Time = '', i3,'' hour'',i3,'' mintues'',f10.4'' seconds'')') hour,minute,second
 !   close(209)
!	write(lst1,'(//5x,''Total CPU Time = '', f10.2)') rtime - stime
!	write(lst2,'(//5x,''Total CPU Time = '', f10.2)') rtime - stime
    
!-------------------------------------------------------------------
    deallocate(atomID,DpSign,ncc)
	deallocate( r, rv, ra,raCV,raDP, raRD, raSP,raCR)
	deallocate( rw, wn)	
	deallocate( chainCentre,sChain)
    
	
	close (lst1)
	close (lst2)
    close (lst3)
    close (lst4)

    if(nDp .gt. 0) then
       close (lst5)
       close (forc)
    endif

	stop

	end

!------------------------------------------------------------------------------------ 

	subroutine readinitconf

	implicit none
	include 'dpdflow.h'

!	Parameters

!	Locals

	integer	k, n

    read(lcnf,*) nWallAtom, nDpEnd, nChainend, nAtom, nDp, RdsDp,      &
                 DpFzn(1:nDp), nChain, ChainLen, initUcell, region,    &
                 regionH, gap, wmingap, wLayer
    
    allocate(atomID(nAtom),DpSign(nAtom),ncc(nAtom,NDIM))
	allocate( r(nAtom,NDIM), rv(nAtom,NDIM), ra(nAtom,NDIM),raCV(nAtom,NDIM), &
	       raDP(nAtom,NDIM), raRD(nAtom,NDIM), raSP(nAtom,NDIM),raCR(nAtom,NDIM))
	allocate( rw(nWallAtom,NDIM), wn(nWallAtom,NDIM))	
	allocate( chainCentre(nChain,NDIM),sChain(nChain))

    do k = 1, NDIM
       read(lcnf,*) (wn(n,k), n = 1, nWallAtom)
       read(lcnf,*) (r(n,k),  n = 1, nAtom)
    enddo

    close (lcnf)

  	do k = 1, NDIM
	   do n = 1, nWallAtom
	      rw(n,k) = r(n,k)
	   enddo
	enddo

    if(nDP .gt. 0) then
! ----- No. of particles of each droplet                         -----
       nPDP = (nDpEnd-nWallAtom)/nDp     
    else
! ----- for surface tension test only in which the second fluid  -----
! ----- is considered as drop particles                          -----
       nPDP = nDpEnd - nWallAtom
    endif

	return

	end

!--------------------------------------------------------------

	subroutine InputData

	implicit none
	include 'dpdflow.h'

!	Parameters

!	Locals
	
!DP	real*8	rfene

	read(inpt,*)
	read(inpt,*) runId
	read(inpt,*)
	read(inpt,*) shearRate
	read(inpt,*)
	read(inpt,*) alphaf, alphafp, alphapp, alphaFD, alphaDD, alphaB, alphaDA, alphaDB
	read(inpt,*)
	read(inpt,*) alphaw, alphawB
	read(inpt,*)
	read(inpt,*) rCut, rCut2 ,rCutDp,rCutDp2
	read(inpt,*)
	read(inpt,*) gammaF, gammaD, gammaFD
	read(inpt,*)
	read(inpt,*) gammaW
	read(inpt,*)
	read(inpt,*) lambda
	read(inpt,*)
	read(inpt,*) density
	read(inpt,*)
	read(inpt,*) temperature, mass
	read(inpt,*)
	read(inpt,*) gravField
	read(inpt,*)
	read(inpt,*) WLadjust
	read(inpt,*)
	read(inpt,*) Hfene, rmaxfene, reqfene
	read(inpt,*)
	read(inpt,*) deltaT
	read(inpt,*)
	read(inpt,*) stepAvg
	read(inpt,*)
	read(inpt,*) stepEquil
	read(inpt,*)
	read(inpt,*) startSample
	read(inpt,*)
	read(inpt,*) stepSample
 	read(inpt,*)
	read(inpt,*) stepLimit
	read(inpt,*)
	read(inpt,*) sizeHistGrid
	read(inpt,*)
	read(inpt,*) stepGrid
	read(inpt,*)
	read(inpt,*) limitGrid
	read(inpt,*)
	read(inpt,*) stepChainProps
	read(inpt,*)
	read(inpt,*) limitChainProps
	read(inpt,*)
	read(inpt,*) nChainConf
	read(inpt,*)
	read(inpt,*) timeSteady

	write(lst1,'(/1x,''runId          :'',  i7  )') runId
	write(lst1,'(1x, ''initUcell      :'', 3i7  )') initUcell
	write(lst1,'(1x, ''alphaf         :'', 4f7.2)') alphaf, alphaFD, alphaDD, alphaB, alphaDA, alphaDB
	write(lst1,'(1x, ''alphaw         :'', 2f7.2)') alphaw, alphawB
	write(lst1,'(1x, ''rCut           :'', 2f7.2)') rCut, rCut2,rCutDp,rCutDp2

!DP	write(lst1,'(1x, ''cigama         :'', 3f7.2)') cigamaF, cigamaD, cigamaFD
!DP	write(lst1,'(1x, ''cigamaw        :'',  f7.2)') cigamaw
	write(lst1,'(1x, ''gamma          :'', 3f7.2)') gammaF, gammaD, gammaFD
	write(lst1,'(1x, ''gammaw         :'',  f7.2)') gammaW

	write(lst1,'(1x, ''lambda         :'',  f7.2)') lambda
	write(lst1,'(1x, ''density        :'',  f7.2)') density
	write(lst1,'(1x, ''temperature    :'',  f7.2)') temperature
	write(lst1,'(1x, ''gravField      :'',  f7.2)') gravField
	write(lst1,'(1x, ''WLadjust       :'',  f7.2)') WLadjust
	write(lst1,'(1x, ''nDroplet       :'',  i7  )') nDp
	write(lst1,'(1x, ''Drop Radius    :'',  f7.2)') RdsDp
	write(lst1,'(1x, ''nChain         :'',  i7  )') nChain
	write(lst1,'(1x, ''ChainLen       :'',  i7  )') ChainLen
	write(lst1,'(1x, ''FENE Params.   :'', 3f7.2)') Hfene, rmaxfene, reqfene
	write(lst1,'(1x, ''deltaT         :'',  f7.4)') deltaT
	write(lst1,'(1x, ''stepAvg        :'',  i7  )') stepAvg
	write(lst1,'(1x, ''stepEquil      :'',  i7  )') stepEquil
	write(lst1,'(1x, ''startSample    :'',  i7  )') startSample
	write(lst1,'(1x, ''stepSample     :'',  i7  )') stepSample
	write(lst1,'(1x, ''stepLimit      :'',  i7  )') stepLimit
	write(lst1,'(1x, ''sizeHistGrid   :'', 3i7  )') sizeHistGrid
	write(lst1,'(1x, ''stepGrid       :'',  i7  )') stepGrid
	write(lst1,'(1x, ''limitGrid      :'',  i7  )') limitGrid
	write(lst1,'(1x, ''stepChainProps :'',  i7  )') stepChainProps
	write(lst1,'(1x, ''limitChainProps:'',  i7  )') limitChainProps
	write(lst1,'(1x, ''nChainConf     :'',  i7  )') nChainConf
	write(lst1,'(1x, ''timSteady      :'',  f7.2)') timeSteady

	write(lst2,'(/1x,''runId          :'',  i7  )') runId
	write(lst2,'(1x, ''initUcell      :'', 3i7  )') initUcell
	write(lst2,'(1x, ''alphaf         :'', 4f7.2)') alphaf, alphaFD, alphaDD, alphaB
	write(lst2,'(1x, ''alphaw         :'',  f7.2)') alphaw
	write(lst2,'(1x, ''rCut           :'', 2f7.2)') rCut, rCut2

!DP	write(lst2,'(1x, ''cigama         :'', 3f7.2)') cigamaF, cigamaD, cigamaFD
!DP	write(lst2,'(1x, ''cigamaw        :'',  f7.2)') cigamaw
	write(lst2,'(1x, ''gammam         :'', 3f7.2)') gammaF, gammaD, gammaFD
	write(lst2,'(1x, ''gammaw         :'',  f7.2)') gammaW

	write(lst2,'(1x, ''lambda         :'',  f7.2)') lambda
	write(lst2,'(1x, ''density        :'',  f7.2)') density
	write(lst2,'(1x, ''temperature    :'',  f7.2)') temperature
	write(lst2,'(1x, ''gravField      :'',  f7.2)') gravField
	write(lst2,'(1x, ''WLadjust       :'',  f7.2)') WLadjust
	write(lst2,'(1x, ''nDroplet       :'',  i7  )') nDp
	write(lst2,'(1x, ''Drop Radius    :'',  f7.2)') RdsDp
	write(lst2,'(1x, ''nChain         :'',  i7  )') nChain
	write(lst2,'(1x, ''ChainLen       :'',  i7  )') ChainLen
	write(lst2,'(1x, ''FENE Params.   :'', 3f7.2)') Hfene, rmaxfene, reqfene
	write(lst2,'(1x, ''deltaT         :'',  f7.4)') deltaT
	write(lst2,'(1x, ''stepAvg        :'',  i7  )') stepAvg
	write(lst2,'(1x, ''stepEquil      :'',  i7  )') stepEquil
	write(lst2,'(1x, ''startSample    :'',  i7  )') startSample
	write(lst2,'(1x, ''stepSample     :'',  i7  )') stepSample
	write(lst2,'(1x, ''stepLimit      :'',  i7  )') stepLimit
	write(lst2,'(1x, ''sizeHistGrid   :'', 3i7  )') sizeHistGrid
	write(lst2,'(1x, ''stepGrid       :'',  i7  )') stepGrid
	write(lst2,'(1x, ''limitGrid      :'',  i7  )') limitGrid
	write(lst2,'(1x, ''stepChainProps :'',  i7  )') stepChainProps
	write(lst2,'(1x, ''limitChainProps:'',  i7  )') limitChainProps
	write(lst2,'(1x, ''nChainConf     :'',  i7  )') nChainConf
	write(lst2,'(1x, ''timSteady      :'',  f7.2)') timeSteady

!	call flush (lst1)
!	call flush (lst2)

	return

	end

!--------------------------------------------------------------	
	
	subroutine SetParams

	implicit none
	include 'dpdflow.h'

!	Parameters
!	Locals

	integer	k
!DP	real*8 d

!	rCut  = 1.0
    rrCut = rCut**2
    r3Cut = rCut**3

    rrCut2 = rCut2**2
    r3Cut2 = rCut2**3

    if(runId .ne. 1) then
        region(3)  = initUcell(3)*gap(3)
        regionH(3) = region(3)/2
    endif

	do k = 1, NDIM
	   cells(k) = region(k) / rCut
	   if(cells(k) .lt. 1) cells(k) = 1
	enddo

	wmingap = wmingap**2
	
	nFreeAtom = nAtom - nWallAtom

	vMag = sqrt(NDIM*(1. - 1. / nFreeAtom)*temperature/mass)

!   hSize = sizeHistGrid(1)*sizeHistGrid(2)
! ----- divide the whole domain into many bins at three directions ---
! ----- (DP--31/01/12)                                             ---
	hSize = sizeHistGrid(1)*sizeHistGrid(2)*sizeHistGrid(3) 
	maxList =  nAtom+cells(1)*cells(2)*cells(3)
    binvolm = region(1)*region(2)*region(3)/hsize
!   binvolm = region(1)*region(2)*initUcell(3)*gap(3)/hsize
print*, maxlist
print*, region(1:NDIM)
print*, natom

!DP	gammaF = 0.5*cigamaF**2/temperature
!	gammaD = 0.5*cigamaD**2/temperature
!   gammaFD= 0.5*cigamaFD**2/temperature
!DP	gammaw = 0.5*cigamaw**2/temperature
    cigamaF  = sqrt(gammaF*2*temperature)
    cigamaD  = sqrt(gammaD*2*temperature)
    cigamaFD = sqrt(gammaFD*2*temperature)
    cigamaW  = sqrt(gammaW*2*temperature)

	sdtinv = 1.0/sqrt(deltaT)
!	alphawf = sqrt(alphaf*alphaw)
! ----- MDPD: an attractive potential is empolyed                -----
    alphawf = -sqrt(alphaf*alphaw)
	wLayer = WLadjust*wLayer
	rrfene = (rmaxfene - reqfene)**2
	
	write(lst1,'(//1x, ''****** Parameters ******'')')
	write(lst1,'(1x, ''Region size       :'', 3f9.4)') region
	write(lst1,'(1x, ''Celle    No.      :'', 3(3x,i5))') cells
	write(lst1,'(1x, ''gaps              :'', 3(3x,f7.4))') gap
	write(lst1,'(1x, ''Size of cellList  :'', 5x, i8)') maxList
	write(lst1,'(1x, ''Wall Molecule No. :'', 5x, i8)') nWallAtom

	write(lst1,'(1x, ''Free Molecule No. :'', 5x, i8)') nFreeAtom
    write(lst1,'(1x, ''Tatal Molecule No.:'', 5x, i8)') nAtom
 	write(lst1,100)
	
!	call flush(lst1)

    write(lst3,'(//1x, ''****** Parameters ******'')')
    write(lst3,'(1x, ''Region size       :'', 3f9.4)') region
    write(lst3,'(1x, ''Celle    No.      :'', 3(3x,i5))') cells
	write(lst3,'(1x, ''gaps              :'', 3(3x,f7.4))') gap
	write(lst3,'(1x, ''Size of cellList  :'', 5x, i8)') maxList
	write(lst3,'(1x, ''Free Molecule No. :'', 5x, i8)') nFreeAtom
	write(lst3,'(1x, ''Wall Molecule No. :'', 5x, i8)') nWallAtom
	write(lst3,'(1x, ''Tatal Molecule No.:'', 5x, i8)') nAtom
	
    write(lst3,'(/3x,''Chain Configuration Data : ''/)')
    
    if(nDp.gt.0) then
       write(lst5,'(/3x,''Drop Configuration Data : ''/)')
       write(lst5,'(1x, ''No. of Droplets         :'', i4)') nDp
       write(lst5,'(1x, ''No. of Particles in each drop :'', i4)') nPDP
    endif

!	call flush(lst3)

100	format(//3x,'stepCount',6x, 'time',5x, 'vSum', 6x, 'E', 7x, &
     	       'E_var', 4x, 'K', 6x, 'K_var', 5x, 'p', 6x, 'p_var')
	return

	end

!--------------------------------------------------------------

	subroutine SetupJob
	
	implicit none
	include 'dpdflow.h'

!	Parameters

!	Locals
	
	integer	n, k
    

!	allocate( profileV(hSize), profileT(hSize),flowvel(hSize,NHIST/2))

	allocate( strsGrid(hSize,NHIST+1), GridChainLen(hSize,NHIST/3),&
					rforce(nAtom,NHIST),histGrid(hSize,NHIST))

	call ranils(290092405)
	call InitVels
	call InitAccels
	call AccumProps (0)

	stepCount = 0
	sInitKinEnergy = 0.
	countChainProps = 0
	
	call GridAverage(0)
	call GridAvChainProps(0)

	countGrid = 0
! ----- times that the chain particle crossing the boundary      -----
! ----- (DP--22/11/11)                                           -----
    do n = 1, nAtom
       do k = 1, NDIM
          ncc(n,k) = 0
       enddo
    enddo              

	return

	end
	
!----------------------------------------------------------------

	subroutine InitVels

	implicit none
	include 'dpdflow.h'

!	parameters

!	Localls

	integer	k, n, i
	real*8	e(NDIM), vTmp(NDIM)

	do k = 1, NDIM
	   do n = nStartAtom, nWallAtom
	      rv(n,k) = 0.
	   enddo
	enddo

	do k = 1, NDIM
	   vTmp(k) = 0.
	enddo

	do n = nWallAtom + 1, nAtom
	   call RandVec3 (e)
	   do k = 1, NDIM
	      rv(n,k) = vMag*e(k)
	      vTmp(k) = vTmp(k) + rv(n,k)
	   enddo
	enddo

	do k = 1, NDIM
	   vTmp(k) = vTmp(k)/nFreeAtom
	   do n = nWallAtom + 1, nAtom
	      rv(n,k) = rv(n,k) - vTmp(k)
	   enddo
	enddo

    if(nDp .gt. 0) then
! ----- fix the frozen particle stationary                       -----
! ----- (DP--12/04/12)                                           -----
       do n = nWallAtom + 1, nDpEnd
          i = int((n - nWallAtom - 1)/nPDP) + 1
          if(DpFzn(i) .eq. 1) then
             rv(n,1:NDIM) = 0.
          endif
          DpSign(n) = 0
       enddo
    !------------------------------------------------------------
       do i = 1, nDp
          do k = 1, NDIM
             do n = nWallAtom + (i-1)*nPDP + 1, nWallAtom + i*nPDP
                CDp0(i,k) = CDp0(i,k) + r(n,k)
             enddo
             CDp0(i,k) = CDp0(i,k) / nPDP
          enddo
       enddo
    endif

	return

	end

!--------------------------------------------------------------

	subroutine InitAccels

	implicit none
	include 'dpdflow.h'

!	Parameters

!	Locals
	
	integer	k, n

	do k = 1, NDIM
	   do n = nStartAtom, nAtom
	      ra(n,k)   = 0.
          raCV(n,k) = 0.
          raCR(n,k) = 0.
          raDP(n,k) = 0.
          raRD(n,k) = 0.
          raSP(n,k) = 0.
	   enddo
	enddo

	return

	end
!! Added by linyuqing
! --------------------------------------------------------------------------------------------------------------------
subroutine readExtraPara
	implicit none
	include 'dpdflow.h'
	integer BnGridH,i,j,k,n
	real*8 alpha,cc,d,T

	open(300, file = './data/ExtraPara.dat')  
	read(300,*)
    read(300,*)
	read(300,*) deltaQ, RDFstepSample
	read(300,*)
	read(300,*) cellength
    read(300,*)
    read(300,*)
	read(300,*) DiffintStep, DiffStep
    read(300,*)
    read(300,*)
	read(300,*) JStep, BStep, rho0, JP0, tau, lpercent

	T=1.0
	alpha=0.1
    cc=4.16
    d=18.
    if (rho0 .ge.0) then
	P0 = 2*alpha*alphaB*(rCut2**4)*(rho0**3)+(alpha*alphaf-2*alpha*alphaB*(rCut2**4)*cc)*(rho0**2)+T*rho0+2*alpha*alphaB*(rCut2**4)*d
    endif
    !print*,tau,rho0,P0
    
    if (stepEquil .gt. (stepLimit-RDFstepSample)) then 
        print*, 'RDFstepSample is too big, please set small one in file ExtraPara'
        pause
        stop
    endif    
    
    if (stepEquil .gt. (stepLimit-DiffStep)) then 
        print*, 'grossStep is too big, please set small one in file ExtraPara'
        pause
        stop
    endif        

	close(300)

end
!--------------------------------------------------------------------
!
! 	subroutine AdjustWallTemp
!
!	implicit none
!	include 'dpdflow.h'
!
!!	Parameters
!
!!	Locals
!
!	integer	k, n
!	real*8	vFac, sum, v(NDIM), tw
!
!	sum = 0.
!	do k = 1, NDIM
!	   v(k) = 0.
!	   do n = 1, nWallAtom
!	      v(k) = v(k) + rv(n,k)
!	   enddo
!	enddo
!	
!	do k = 1, NDIM
!	   v(k) = v(k)/nWallAtom
!	enddo
!	
!	do k = 1, NDIM
!	   do n = 1, nWallAtom
!	      rv(n,k) = rv(n,k) - v(k)
!	      sum = sum + rv(n,k)**2
!	   enddo
!	enddo
!
!   vFac = vMag/sqrt(sum/nWallAtom)
!	do k = 1, NDIM
!	   do n = 1, nWallAtom
!	      rv(n,k) = rv(n,k)*vFac
!	   enddo
! 	enddo
!
!!	check wqll temperaure
!
!! 	sum = 0.
!! 	do k = 1, NDIM
!! 	  do n = 1, nWallAtom
!! 	    sum = sum + rv(n,k)**2
!! 	  enddo
!! 	enddo
!! 	tw = sum/(3.*(nWallAtom - 1.))
!! 	print*, 'tw = ', tw
!
!	return
!
!	end
!
!-------------------------------------------------------------
!
!	subroutine KeepWallTemp
!
!	implicit none
!	include 'dpdflow.h'
!
!!	parameters
!
!!	Localls
!
!	integer	k, n
!	real*8	e(NDIM), vTmp(NDIM)
!
!	do k = 1, NDIM
!	  vTmp(k) = 0.
!	enddo
!
!	do n = 1, nWallAtom
!	   call RandVec3 (e)
!	   do k = 1, NDIM
!	      rv(n,k) = vMag*e(k)
!	      vTmp(k) = vTmp(k) + rv(n,k)
!	   enddo
!	enddo
!
!	do k = 1, NDIM
!	   vTmp(k) = vTmp(k)/nWallAtom
!	   do n = 1, nWallAtom
!	      rv(n,k) = rv(n,k) - vTmp(k)
!	   enddo
!	enddo
!
!	return
!
!	end
!
!-----------------------------------------------------------------------------------
!	
!	subroutine checkpst(n)
!
!	implicit none
!	include 'dpdflow.h'
!	
!	integer	k, n
!
!	write(*,'(''stepCount = '',i5)') stepCount
!	write(*,'(''r(n)  = '', 3f10.4)') (r(n,k), k = 1,3)
!	write(*,'(''rv(n) = '', 3f10.4)') (rv(n,k), k = 1,3)
!!	call flush(6)
!	pause
!
!	return
!
!	end
!
!-----------------------------------------------------------------------
!	
!	subroutine checknbr
!
!	implicit none
!	include 'dpdflow.h'
!
!	integer i, j, k
!	real*8	dr
!	print*, 'timeNow = ', timeNow
!	do i = 1, nAtom
!	  dr = 0.
!	  do k = 1, NDIM
!	    dr = dr + (r(538,k) - r(i,k))**2
!	  enddo
!	  if(dr .le. rrCut) then
!	    print*, ' atom = ', i
!	  endif
!	enddo
!
!	return
!
!	end
!
!--------------------------------------------------------------------------
!
!	subroutine EvalProfile
!
!	implicit none
!	include 'dpdflow.h'
!
!!	Parameters
!
!!	Locals
!
!	integer	k, n
!
!!	nEval = nEval + 1.0
!	do n = 1, sizeHistGrid(2)
!	  profileV(n) = 0.
!	  profileT(n) = 0.
!	enddo
!
!	do n = 1, hSize
!	  k = (n - 1)/sizeHistGrid(1) + 1
!	  profileV(k) = profileV(k) + histGrid(n,3)
!	  profileT(k) = profileT(k) + histGrid(n,2)
!	enddo
!
!	do n = 1, sizeHistGrid(2)
!	  profileV(n) = profileV(n)/sizeHistGrid(1)
!	  profileT(n) = profileT(n)/sizeHistGrid(1)
!	enddo
!
!	return
!
!	end
!
!---------------------------------------------------------------
!
!	subroutine PrintProfile
!
!	implicit none
!	include 'dpdflow.h'
!
!	Parameters
!
!	Locals
!
!	integer	n
!	real	zVal, Velocity, Temperat, MolecNo
!
!	write(lst2, '(/5x, ''Velocity Profile'')')
!	write(lst2, '(5x, ''time = '', f9.4)') timeNow
!	write(lst2, '(3x, ''No'', 6x, ''Z'', 9x, ''Vz'',10x,''T'',&
!	                 7x, ''Ni/<Ni>'')')
!
!	do n = 1, sizeHistGrid(2)
!	  zVal = (n - 0.5)/sizeHistGrid(2)*region(NDIM) - regionH(NDIM)
!	  write(lst2, 100) n, zVal, profileV(n), profileT(n), histGrid(n,1)
!	enddo
!
!	nEval = 0.
!
! 100	format(2x, i3, 2x, f8.3, 3(2x, f9.4))
!
!	return
!
!	end
!
!------------------------------------------------------------------
!	
!	subroutine getCPUtime (seconds)
!
!	implicit none
!!	Parameters
!
!    real*4, intent(out):: seconds
!
!!	Locals
!
!    real*4   tarray(2), etime
!    external etime
!
!    seconds= etime(tarray)
!
!    return
!
!    end
!
!!! ----------------------------------------------------------------------
