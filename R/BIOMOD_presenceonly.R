
BIOMOD_presenceonly <- function(modeling.output = NULL, EM.output = NULL, bg.env = NULL, perc = 0.9, save.output = T){
  # if(!require(PresenceAbsence)){stop("PresenceAbsence package required!")}
  requireNamespace('PresenceAbsence', quietly = TRUE)
  
  myModelEval <- myBiomodProjFF <- NULL
  
  if(!is.null(modeling.output)){  
    calib.lines<-get(load(modeling.output@calib.lines@link))[,,1]
    myResp <- get(load(modeling.output@formated.input.data@link))@data.species
    
    myModelEval <- get_evaluations(modeling.output,as.data.frame=T)
    myModelEval[,1] <- as.character(myModelEval[,1])
    for(i in 1:nrow(myModelEval)){myModelEval[i,1] <- paste(c(modeling.output@sp.name,strsplit(as.character(myModelEval[i,1]),split="_")[[1]][3:1]),collapse="_")  } 
    
    myModelPred <- get_predictions(modeling.output,as.data.frame=T)
    if(!is.null(bg.env)){
      myModelPred.pres <- myModelPred[myResp==1,]
      myBiomodProj.eval <- BIOMOD_Projection(
        new.env = bg.env,
        proj.name = paste(modeling.output@modeling.id,"cv_EF_eval",sep="_"),
        modeling.output = modeling.output,
        build.clamping.mask = F)      
      myModelPred <- as.data.frame(myBiomodProj.eval@proj@val)
      ### Change the colnames to the real model names
      colnames(myModelPred) <- 
        paste(
          modeling.output@sp.name,
          rep(dimnames(myBiomodProj.eval@proj@val)[[4]],prod(dim(myBiomodProj.eval@proj@val)[2:3])),
          rep(dimnames(myBiomodProj.eval@proj@val)[[3]],each = dim(myBiomodProj.eval@proj@val)[2]),
          rep(dimnames(myBiomodProj.eval@proj@val)[[2]],dim(myBiomodProj.eval@proj@val)[3]), sep='_')
    }
    if(modeling.output@has.evaluation.data == T){
      myModelPred.eval  <- as.data.frame(get(load(paste(modeling.output@"sp.name","/.BIOMOD_DATA/",modeling.output@modeling.id,"/models.prediction.eval", sep=""))))
      for(i in 1:ncol(myModelPred.eval)){colnames(myModelPred.eval)[i] <- paste(c(modeling.output@sp.name,strsplit(colnames(myModelPred.eval)[i],split="[.]")[[1]][3:1]),collapse="_")  }       
    }
  }
  
  if(!is.null(EM.output)){
    if(EM.output@em.by!='PA_dataset+repet'){stop("em.by of 'BIOMOD.EnsembleModeling' must be 'PA_dataset+repet'")} 
    myModelEvalEF <- get_evaluations(EM.output,as.data.frame=T)
    myModelEvalEF[,1] <- paste(modeling.output@sp.name,as.character(myModelEvalEF[,1]),sep="_")
    #for(i in 1:nrow(myModelEvalEF)){myModelEvalEF[i,1] <- paste("EF",strsplit(as.character(myModelEvalEF[,1]),split="_")[[i]][2],"AllData",sep="_")}
    if(!is.null(modeling.output)){
      myModelEval <- rbind(myModelEval, myModelEvalEF)
    }
    
    myBiomodProjFF <- get_predictions(EM.output,as.data.frame=T)  
    
    if(!is.null(bg.env)){
      myBiomodProjFF.pres <- as.data.frame(myBiomodProjFF[myResp==1,])
      colnames(myBiomodProjFF.pres) <- colnames(myBiomodProjFF)
      myBiomodProjFF <- BIOMOD_EnsembleForecasting(
        proj.name = paste(modeling.output@modeling.id,"cv_EF_bg",sep="_"), 
        projection.output = myBiomodProj.eval,
        EM.output = EM.output)    
      myBiomodProjFF <- as.data.frame(myBiomodProjFF@proj@val)     
      myModelPred.pres <- cbind(myModelPred.pres,myBiomodProjFF.pres)
    }
    myModelPred <- cbind(myModelPred, myBiomodProjFF)
    
    if(modeling.output@has.evaluation.data == T){
      myBiomodProjFF.eval <- get_predictions(EM.output,as.data.frame=T,evaluation=T)  
      
      #colnames(myBiomodProjFF.eval) <- gsub("AllAlgos_ROC_EMwmean","EF",  colnames(myBiomodProjFF.eval))
      myModelPred.eval <- cbind(myModelPred.eval, myBiomodProjFF.eval)      
    }  
  }
  
  mpa.eval <- boyce.eval <- myModelEval[!duplicated(myModelEval[,1]),]
  boyce.eval$Eval.metric <- "boyce"
  mpa.eval$Eval.metric <- "mpa"
  boyce.eval[,3:7]<-mpa.eval[,3:7]<-NA
  
  ###MPA & BOYCE     
  for(i in 1:nrow(boyce.eval)){
    n <- length(strsplit(as.character(boyce.eval[i,1]),split="_")[[1]])
    tec <- paste(strsplit(as.character(boyce.eval[i,1]),split="_")[[1]][3:n],collapse="_") 
    Model.name <- boyce.eval[i,1]
    run <- strsplit(Model.name,split="_")[[1]][c(grep("RUN",strsplit(Model.name,split="_")[[1]]),grep("Full",strsplit(Model.name,split="_")[[1]]))]
    
    #### CORRECTION ------------------------------------------------------------------------
    if(inherits(calib.lines, "matrix")){
      ind.eval = which(calib.lines[,paste("_",run, sep="")] == FALSE) #### CORRECTION
    }else{
      ind.eval = which(calib.lines == FALSE) #### CORRECTION
    }
    
    if(length(ind.eval)==0){      #this is the full model ##### CORRECTION
      if(is.null(bg.env)){
        # if(inherits(calib.lines, "matrix")){ #### PROBLEM : this part gives problem with the cbind after (not same number of rows)
        #   test <- myResp
        #   Pred<-myModelPred[,Model.name]
        # }else{
          test <- myResp[calib.lines]     
          Pred <- myModelPred[calib.lines,Model.name]
        # }
      }else{
        test <- c(myResp[myResp==1],rep(0,nrow(bg.env)))    
        Pred <- c(myModelPred.pres[,Model.name],myModelPred[,Model.name])       
      }
    }else{
      if(is.null(bg.env)){
        test <- myResp[ind.eval] #### CORRECTION
        Pred <- myModelPred[ind.eval,Model.name] #### CORRECTION
      }else{
        test <- c(myResp[ind.eval & myResp==1],rep(0,nrow(bg.env))) #### CORRECTION
        Pred <- c(myModelPred.pres[ind.eval & myResp==1,Model.name],myModelPred[,Model.name])  #### CORRECTION
      }
    }
    #### CORRECTION ------------------------------------------------------------------------
    
    
    ind.1 = which(test == 1)
    ind.notNA = which(!is.na(Pred))
    ind.obs = intersect(ind.1, ind.notNA)
    
    if (length(ind.obs) > 0){ #### CORRECTION
      boy <- ecospat::ecospat.boyce(fit=Pred[ind.notNA],obs=Pred[ind.obs], PEplot=F) #### CORRECTION
      boyce.eval[boyce.eval[,1]==Model.name,3] <- boy$Spearman.cor
      if( sum(boy$F.ratio<1,na.rm=T)>0){
        boyce.eval[boyce.eval[,1]==Model.name,5] <- round(boy$HS[max(which(boy$F.ratio<1))],0)
        DATA<-cbind(1:length(Pred), test, Pred/1000) #### PROBLEM
        DATA[is.na(DATA[,2]),2] <- 0
        DATA <- DATA[stats::complete.cases(DATA),]
        if(!is.na(round(boy$HS[max(which(boy$F.ratio<1))],0)/1000)){
          EVAL<-presence.absence.accuracy(DATA, threshold=round(boy$HS[max(which(boy$F.ratio<1))],0)/1000) 
          boyce.eval[boyce.eval[,1]==Model.name,6] <-  EVAL$sensitivity 
          boyce.eval[boyce.eval[,1]==Model.name,7] <-  EVAL$specificity
        }else{boyce.eval[boyce.eval[,1]==Model.name,6:7] <-  NA}
      }else{
        boyce.eval[boyce.eval[,1]==Model.name,7] <-  boyce.eval[boyce.eval[,1]==Model.name,6] <-  boyce.eval[boyce.eval[,1]==Model.name,5] <- NA 	
      }
      
      mpa.eval[mpa.eval[,1]==Model.name,5] <- ecospat::ecospat.mpa(Pred[ind.obs], perc = perc) #### CORRECTION
      EVAL<-presence.absence.accuracy(DATA, threshold=ecospat::ecospat.mpa(Pred[ind.obs], perc = perc)/1000) #### CORRECTION
      mpa.eval[mpa.eval[,1]==Model.name,6] <-  EVAL$sensitivity 
      mpa.eval[mpa.eval[,1]==Model.name,7] <-  EVAL$specificity  
    }
    
    if(modeling.output@has.evaluation.data == T){
      myResp.eval <- get(load(modeling.output@formated.input.data@link))@eval.data.species
      Pred.eval <- myModelPred.eval[,Model.name]
      
      boy <- ecospat::ecospat.boyce(fit=Pred.eval,obs=Pred.eval[myResp.eval==1 & ind.1], PEplot=F) #### CORRECTION
      boyce.eval[boyce.eval[,1]==Model.name,"Evaluating.data"] <- boy$Spearman.cor
      
      mpa.eval[mpa.eval[,1]==Model.name,"Evaluating.data"] <- ecospat::ecospat.mpa(Pred.eval[myResp.eval==1 & ind.1], perc = perc) #### CORRECTION
    }
  }
  myModelEval[,6:7] <- round(myModelEval[,6:7],1)
  boyce.eval[,6:7] <- round(boyce.eval[,6:7]*100,1)
  mpa.eval[,6:7] <- round(mpa.eval[,6:7]*100,1)  
  
  if(modeling.output@has.evaluation.data == T){
    if(!is.null(EM.output)){
      output <- list(eval=rbind(myModelEval,boyce.eval,mpa.eval),myBiomodProjFF=myBiomodProjFF,myBiomodProjEF.eval=myBiomodProjFF.eval) 
    }else{
      output <- list(eval=rbind(myModelEval,boyce.eval,mpa.eval))      
    }
    if(save.output){
      if(!is.null(modeling.output)){
        sp<-modeling.output@sp.name}
      if(!is.null(EM.output)){
        sp<-EM.output@sp.name}      
      save(output, paste(sp, "/.BIOMOD_DATA/",modeling.output@modeling.id,"/presenceonlyevaluation_",sp, sep=""))
    }
    return(output)
  }else{
    if(!is.null(EM.output)){
      output <- list(eval=rbind(myModelEval,boyce.eval,mpa.eval),myBiomodProjFF=myBiomodProjFF)
    }else{
      output <- list(eval=rbind(myModelEval,boyce.eval,mpa.eval))      
    }
    if(save.output){
      if(!is.null(modeling.output)){
        sp<-modeling.output@sp.name}
      if(!is.null(EM.output)){
        sp<-EM.output@sp.name}      
      save(output, file=paste(sp, "/.BIOMOD_DATA/",modeling.output@modeling.id,"/presenceonlyevaluation_",sp, sep=""))
    }
    return(output)
  }
}
